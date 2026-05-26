from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle
from .models import Customer, WalletTransaction
from authapp.utils import require_org, log_activity
from authapp.permissions import IsCustomerEditor


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
def customer_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == "GET":
        search = request.query_params.get("search", "").strip()
        customers = Customer.objects.filter(organization=org).order_by("name")
        if search:
            customers = customers.filter(name__icontains=search)
        return Response([c.to_list_dict() for c in customers])

    data = request.data
    name = data.get("name", "").strip()
    phone = data.get("phone", "").strip()
    if not name:
        return Response(
            {"detail": "Name is required"}, status=status.HTTP_400_BAD_REQUEST
        )
    if not phone:
        return Response(
            {"detail": "Phone is required"}, status=status.HTTP_400_BAD_REQUEST
        )
    if Customer.objects.filter(organization=org, phone=phone).exists():
        return Response(
            {"detail": "A customer with this phone number already exists"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    customer = Customer.objects.create(
        organization=org,
        name=name,
        phone=phone,
        is_wholesale=bool(data.get("is_wholesale", False)),
        is_network_patient=bool(data.get("is_network_patient", False)),
        email=data.get("email", ""),
        address=data.get("address", ""),
        allergies=data.get("allergies") or [],
        chronic_conditions=data.get("chronic_conditions") or [],
        current_medications=data.get("current_medications") or [],
    )
    log_activity(request, action='Create Customer', category='customers',
                 description=f'New customer "{customer.name}" registered')
    return Response(customer.to_detail_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
def customer_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)

    if request.method == "GET":
        return Response(customer.to_detail_dict())

    if request.method in ("PUT", "PATCH"):
        data = request.data
        customer.name = data.get("name", customer.name)
        customer.phone = data.get("phone", customer.phone)
        customer.is_wholesale = data.get("is_wholesale", customer.is_wholesale)
        if "is_network_patient" in data:
            customer.is_network_patient = bool(data["is_network_patient"])
        customer.email = data.get("email", customer.email)
        customer.address = data.get("address", customer.address)
        if "allergies" in data:
            customer.allergies = data["allergies"] or []
        if "chronic_conditions" in data:
            customer.chronic_conditions = data["chronic_conditions"] or []
        if "current_medications" in data:
            customer.current_medications = data["current_medications"] or []
        if "blood_group" in data:
            customer.blood_group = data["blood_group"] or ''
        if "date_of_birth" in data:
            from datetime import date
            try:
                customer.date_of_birth = date.fromisoformat(data["date_of_birth"]) if data["date_of_birth"] else None
            except (ValueError, TypeError):
                pass
        # HMO fields
        if "hmo_provider" in data:
            customer.hmo_provider = data["hmo_provider"] or ''
        if "hmo_plan_name" in data:
            customer.hmo_plan_name = data["hmo_plan_name"] or ''
        if "hmo_card_number" in data:
            customer.hmo_card_number = data["hmo_card_number"] or ''
        if "hmo_coverage_percent" in data:
            try:
                val = data["hmo_coverage_percent"]
                customer.hmo_coverage_percent = max(0, min(100, float(val))) if val is not None else None
            except (ValueError, TypeError):
                pass
        if "hmo_expiry_date" in data:
            from datetime import date
            try:
                customer.hmo_expiry_date = date.fromisoformat(data["hmo_expiry_date"]) if data["hmo_expiry_date"] else None
            except (ValueError, TypeError):
                pass
        customer.save()
        log_activity(request, action='Update Customer', category='customers',
                     description=f'Updated customer "{customer.name}"')
        return Response(customer.to_detail_dict())

    customer_name = customer.name
    customer.delete()
    log_activity(request, action='Delete Customer', category='customers',
                 description=f'Deleted customer "{customer_name}"')
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
def wallet_transactions(request, pk):
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    # Oldest first so we can compute running balance forward
    txns = list(customer.wallet_transactions.order_by("created"))

    # Signed delta per txn type (amounts are always stored positive)
    def _delta(t):
        return float(t.amount) if t.txn_type in ("topup", "refund") else -float(t.amount)

    # Reconstruct balance before the first transaction
    total_delta = sum(_delta(t) for t in txns)
    running = float(customer.wallet_balance) - total_delta

    result = []
    for t in txns:
        running += _delta(t)
        d = t.to_api_dict()
        d["balanceAfter"] = round(running, 2)
        result.append(d)

    result.reverse()  # return newest-first for display
    return Response(result)


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
@throttle_classes([ScopedRateThrottle])
def wallet_topup(request, pk):
    request.throttle_scope = 'wallet'
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    try:
        amount = float(request.data.get("amount", 0))
    except (ValueError, TypeError):
        return Response({"detail": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)
    note = request.data.get("note", "")

    if amount <= 0:
        return Response(
            {"detail": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )
    if amount > 10000000:
        return Response(
            {"detail": "Amount exceeds maximum limit"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    with transaction.atomic():
        customer = Customer.objects.select_for_update().get(pk=pk)
        customer.wallet_balance = float(customer.wallet_balance) + amount
        customer.save()
        txn = WalletTransaction.objects.create(
            customer=customer, txn_type="topup", amount=amount, note=note
        )
    log_activity(request, action='Wallet Top-up', category='customers',
                 description=f'Wallet top-up ₦{amount:,.0f} for "{customer.name}"')
    return Response(
        {
            "walletBalance": float(customer.wallet_balance),
            "transaction": txn.to_api_dict(),
        }
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
@throttle_classes([ScopedRateThrottle])
def wallet_deduct(request, pk):
    request.throttle_scope = 'wallet'
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    try:
        amount = float(request.data.get("amount", 0))
    except (ValueError, TypeError):
        return Response({"detail": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)
    note = request.data.get("note", "")

    if amount <= 0:
        return Response(
            {"detail": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )

    with transaction.atomic():
        # Re-read within transaction to avoid race condition
        customer = Customer.objects.select_for_update().get(pk=pk)
        # Wallet is allowed to go negative (credit/debt for registered customers)
        customer.wallet_balance = float(customer.wallet_balance) - amount
        customer.save()
        txn = WalletTransaction.objects.create(
            customer=customer, txn_type="deduct", amount=amount, note=note
        )
    log_activity(request, action='Wallet Deduct', category='customers',
                 description=f'Wallet deduction ₦{amount:,.0f} from "{customer.name}"')
    return Response(
        {
            "walletBalance": float(customer.wallet_balance),
            "transaction": txn.to_api_dict(),
        }
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
def customer_sales(request, pk):
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    sales = customer.sales.order_by("-created")
    return Response([s.to_api_dict() for s in sales])


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
@throttle_classes([ScopedRateThrottle])
def wallet_reset(request, pk):
    request.throttle_scope = 'wallet'
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    old_balance = float(customer.wallet_balance)
    with transaction.atomic():
        customer.wallet_balance = 0
        customer.save()
        if old_balance != 0:
            txn_type = "deduct" if old_balance > 0 else "topup"
            WalletTransaction.objects.create(
                customer=customer,
                txn_type=txn_type,
                amount=abs(old_balance),
                note="Wallet reset",
            )
    return Response({"walletBalance": 0.0})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def search_customers_global(request):
    """
    GET /api/customers/search/?q=<term>[&global=true]
    Searches customers by name or phone number.
    With global=true: searches across ALL active organizations in the system
    (for the prescription "find patient from any pharmacy" use-case).
    Without global or global=false: searches only within the caller's org.
    Results include pharmacy_name and pharmacy_id so the caller knows the source.
    """
    q = request.query_params.get('q', '').strip()
    if len(q) < 2:
        return Response([])

    from django.db.models import Q as _Q
    from customers.models import Customer

    is_global = request.query_params.get('global', '').lower() in ('1', 'true')

    if is_global:
        # Search all orgs — phone is the most reliable identifier across pharmacies
        qs = Customer.objects.filter(
            _Q(name__icontains=q) | _Q(phone__icontains=q)
        ).select_related('organization').order_by('name')[:40]
    else:
        org = getattr(request.user, 'organization', None)
        if org is None:
            return Response([])
        qs = Customer.objects.filter(
            organization=org
        ).filter(
            _Q(name__icontains=q) | _Q(phone__icontains=q)
        ).order_by('name')[:40]

    results = []
    for c in qs:
        results.append({
            'id':                 c.id,
            'name':               c.name,
            'phone':              c.phone,
            'is_wholesale':       c.is_wholesale,
            'is_network_patient': c.is_network_patient,
            'pharmacy_name':      c.organization.name if c.organization_id else None,
            'pharmacy_id':        c.organization_id,
        })
    return Response(results)


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsCustomerEditor])
@throttle_classes([ScopedRateThrottle])
def record_payment(request, pk):
    request.throttle_scope = 'wallet'
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    amount = float(request.data.get("amount", 0))
    method = request.data.get("method", "cash")
    if amount <= 0:
        return Response(
            {"detail": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )
    if float(customer.outstanding_debt) < amount:
        return Response(
            {"detail": f"Payment exceeds debt of {customer.outstanding_debt}"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    with transaction.atomic():
        customer.outstanding_debt = float(customer.outstanding_debt) - amount
        customer.save()
        WalletTransaction.objects.create(
            customer=customer,
            txn_type="deduct",
            amount=amount,
            note=f"Debt payment via {method}",
        )
    return Response({"outstandingDebt": float(customer.outstanding_debt)})
