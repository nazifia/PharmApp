from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, throttle_classes
from rest_framework.response import Response
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle
from .models import Customer, WalletTransaction
from authapp.utils import require_org


@api_view(["GET", "POST"])
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
        is_wholesale=data.get("is_wholesale", False),
        email=data.get("email", ""),
        address=data.get("address", ""),
    )
    return Response(customer.to_detail_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
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
        customer.email = data.get("email", customer.email)
        customer.address = data.get("address", customer.address)
        customer.save()
        return Response(customer.to_detail_dict())

    customer.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
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
    return Response(
        {
            "walletBalance": float(customer.wallet_balance),
            "transaction": txn.to_api_dict(),
        }
    )


@api_view(["POST"])
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
    return Response(
        {
            "walletBalance": float(customer.wallet_balance),
            "transaction": txn.to_api_dict(),
        }
    )


@api_view(["GET"])
def customer_sales(request, pk):
    org, err = require_org(request)
    if err:
        return err
    customer = get_object_or_404(Customer, pk=pk, organization=org)
    sales = customer.sales.order_by("-created")
    return Response([s.to_api_dict() for s in sales])


@api_view(["POST"])
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


@api_view(["POST"])
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
