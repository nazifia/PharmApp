import re
import uuid
from datetime import date as _date
from decimal import Decimal
from django.db import transaction
from django.db.models import Q, Sum, F
from django.utils import timezone
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle

from inventory.models import Item
from customers.models import Customer, WalletTransaction
from authapp.models import PharmUser
from branches.models import Branch
from authapp.utils import require_org, log_activity, normalize_ng_phone
from authapp.permissions import require_permission, REPORTS_ROLES
from .models import (
    Cashier,
    Sale,
    SaleItem,
    DispensingLog,
    PaymentRequest,
    PaymentRequestItem,
    ReceiptPayment,
    ReturnRecord,
    ExpenseCategory,
    Expense,
    Supplier,
    Procurement,
    ProcurementItem,
    StockCheck,
    StockCheckItem,
    Notification,
    Shift,
)


# ═══════════════════════════════════════════════════════════════════════════════
#  CHECKOUT
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def checkout(request):
    """
    Process a sale. Supports split payments, wallet, cashier assignment.
    """
    request.throttle_scope = 'checkout'
    data = request.data
    org, err = require_org(request)
    if err:
        return err
    customer_id = data.get("customerId")
    cashier_id = data.get("cashierId")
    branch_id = data.get("branch_id") or data.get("branchId")
    is_wholesale = bool(data.get("isWholesale") or False)

    # Enforce POS permission (honors individual overrides)
    perm_key = 'wholesalePOS' if is_wholesale else 'retailPOS'
    err = require_permission(request, perm_key)
    if err:
        return err
    items_data = data.get("items", [])
    payment = data.get("payment", {})
    payment_method = data.get("paymentMethod") or "cash"
    buyer_name = data.get("buyerName", "")
    buyer_address = data.get("buyerAddress", "")

    if not items_data:
        return Response(
            {"detail": "No items in cart"}, status=status.HTTP_400_BAD_REQUEST
        )

    customer = None
    if customer_id:
        try:
            customer = Customer.objects.get(pk=customer_id, organization=org)
        except Customer.DoesNotExist:
            return Response(
                {"detail": "Customer not found"},
                status=status.HTTP_400_BAD_REQUEST,
            )

    cashier = None
    if cashier_id:
        try:
            cashier = Cashier.objects.get(pk=cashier_id, is_active=True, user__organization=org)
        except Cashier.DoesNotExist:
            return Response(
                {"detail": "Cashier not found"},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # Validate items and stock
    expected_store = "wholesale" if is_wholesale else "retail"
    total = Decimal("0")
    discount_total = Decimal("0")
    resolved = []
    for i_data in items_data:
        item_id = i_data.get("itemId")
        barcode = i_data.get("barcode", "")
        try:
            qty = Decimal(str(i_data.get("quantity", 1)))
            price = Decimal(str(i_data.get("price", 0)))
            discount = Decimal(str(i_data.get("discount", 0)))
        except (ValueError, TypeError, Exception):
            return Response(
                {"detail": "Invalid quantity, price, or discount value"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if qty <= 0:
            return Response(
                {"detail": "Quantity must be positive"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        item = None
        if item_id:
            item = Item.objects.filter(pk=item_id, organization=org).first()
        elif barcode:
            item = Item.objects.filter(barcode=barcode, organization=org).first()

        if item and item.store != expected_store:
            return Response(
                {
                    "detail": (
                        f"Item '{item.name}' belongs to the {item.store} store "
                        f"and cannot be sold in a {expected_store} transaction."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if item and item.stock < qty:
            return Response(
                {
                    "detail": f"Insufficient stock for {item.name}: {item.stock} available, {qty} requested"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        line_total = (price * qty) - discount
        total += line_total
        discount_total += discount
        resolved.append(
            {
                "item": item,
                "qty": qty,
                "price": price,
                "discount": discount,
                "barcode": barcode,
                "name": i_data.get("name", item.name if item else ""),
                "brand": i_data.get("brand", item.brand if item else ""),
                "dosage_form": i_data.get(
                    "dosageForm", item.dosage_form if item else ""
                ),
                "unit": i_data.get("unit", item.unit if item else ""),
            }
        )

    # Silent consultation surcharge — folded into the order total but never
    # written as a SaleItem, so it does not appear as a receipt line.
    try:
        consultation_fee = Decimal(str(data.get("consultationFee", 0) or 0))
    except (ValueError, TypeError, Exception):
        consultation_fee = Decimal("0")
    if consultation_fee < 0:
        consultation_fee = Decimal("0")
    total += consultation_fee

    # Validate payment
    cash = Decimal(str(payment.get("cash", 0)))
    pos = Decimal(str(payment.get("pos", 0)))
    transfer = Decimal(str(payment.get("bankTransfer", 0)))
    wallet = Decimal(str(payment.get("wallet", 0)))
    payment_total = cash + pos + transfer + wallet

    if payment_total < total:
        return Response(
            {"detail": f"Payment ({payment_total}) is less than order total ({total})"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Overpayment is cash tendered; change is returned from the cash drawer.
    # Store the cash actually kept so payment fields sum to total_amount and
    # reports reconcile with revenue.
    change = payment_total - total
    if change > 0:
        cash = max(cash - change, Decimal("0"))

    wallet_insufficient = False
    if wallet > 0:
        if not customer:
            return Response(
                {"detail": "Wallet payment requires a customer"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Wallet is allowed to go negative (credit/debt for registered customers).
        # When it does, the sale is booked as "credit": still dispensed and logged
        # to the customer's wallet transactions, but excluded from daily sales total.
        wallet_insufficient = Decimal(str(customer.wallet_balance)) < wallet

    branch = None
    if branch_id:
        try:
            branch = Branch.objects.get(pk=int(branch_id), organization=org)
        except (Branch.DoesNotExist, ValueError, TypeError):
            pass

    try:
      # HMO / insurance
      hmo_card_number      = data.get('hmo_card_number', '')
      hmo_provider         = data.get('hmo_provider', '')
      hmo_coverage_percent = data.get('hmo_coverage_percent')
      hmo_amount           = Decimal(str(data.get('hmo_amount', 0) or 0))

      with transaction.atomic():
        dispenser = request.user if request.user.is_authenticated else None
        open_shift = (
            Shift.objects.filter(organization=org, staff=dispenser, status=Shift.STATUS_OPEN).first()
            if dispenser else None
        )
        sale = Sale.objects.create(
            organization=org,
            branch=branch,
            customer=customer,
            cashier=cashier,
            dispenser=dispenser,
            shift=open_shift,
            total_amount=total,
            discount_total=discount_total,
            consultation_fee=consultation_fee,
            payment_cash=cash,
            payment_pos=pos,
            payment_transfer=transfer,
            payment_wallet=wallet,
            payment_method=payment_method,
            is_wholesale=is_wholesale,
            status="credit" if wallet_insufficient else "completed",
            buyer_name=buyer_name,
            buyer_address=buyer_address,
            hmo_card_number=hmo_card_number or '',
            hmo_provider=hmo_provider or '',
            hmo_coverage_percent=hmo_coverage_percent if hmo_coverage_percent is not None else None,
            hmo_amount=hmo_amount,
        )

        for ri in resolved:
            item = ri["item"]
            qty = ri["qty"]
            if item:
                item = Item.objects.select_for_update().get(pk=item.pk)
                if item.store != expected_store:
                    raise ValueError(
                        f"Store mismatch for {item.name}: expected {expected_store}"
                    )
                if item.stock < qty:
                    raise ValueError(f"Insufficient stock for {item.name}")
                item.stock -= qty
                item.save()

            SaleItem.objects.create(
                sale=sale,
                item=item,
                name=ri["name"],
                brand=ri["brand"],
                dosage_form=ri["dosage_form"],
                unit=ri["unit"],
                quantity=qty,
                price=ri["price"],
                discount=ri["discount"],
                barcode=ri["barcode"],
            )

            DispensingLog.objects.create(
                user=request.user if request.user.is_authenticated else None,
                sale=sale,
                item=item,
                name=ri["name"],
                brand=ri["brand"],
                dosage_form=ri["dosage_form"],
                unit=ri["unit"],
                quantity=qty,
                amount=ri["price"] * qty,
                discount_amount=ri["discount"],
            )

        if customer and wallet > 0:
            customer.wallet_balance = Decimal(str(customer.wallet_balance)) - wallet
            customer.last_visit = timezone.localdate()
            customer.save()
            WalletTransaction.objects.create(
                customer=customer,
                txn_type="purchase",
                amount=wallet,
                note=f"Sale #{sale.id}",
            )

        if customer:
            customer.last_visit = timezone.localdate()
            customer.save()

        # Record split payments
        if payment_method == "split":
            for method, amt in [
                ("cash", cash),
                ("pos", pos),
                ("transfer", transfer),
                ("wallet", wallet),
            ]:
                if amt > 0:
                    ReceiptPayment.objects.create(
                        receipt=sale, amount=amt, payment_method=method
                    )

    except ValueError as e:
        return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    sale_type = 'Wholesale' if is_wholesale else 'Retail'
    item_count = len(items_data)
    log_activity(request, action='Sale', category='sales',
                 description=f'{sale_type} checkout — ₦{float(sale.total_amount):,.0f} ({item_count} item{"s" if item_count != 1 else ""})')
    return Response(sale.to_api_dict(), status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════════════════
#  SALES / RECEIPTS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def sale_list(request):
    org, err = require_org(request)
    if err:
        return err
    sales = Sale.objects.filter(organization=org).select_related("customer", "cashier")
    date_from = request.query_params.get("from")
    date_to = request.query_params.get("to")
    customer_id = request.query_params.get("customerId")
    search = request.query_params.get("search", "").strip()

    if date_from:
        sales = sales.filter(created__date__gte=date_from)
    if date_to:
        sales = sales.filter(created__date__lte=date_to)
    if customer_id:
        sales = sales.filter(customer_id=customer_id)
    if search:
        sales = sales.filter(
            Q(receipt_id__icontains=search)
            | Q(customer__name__icontains=search)
            | Q(buyer_name__icontains=search)
        )

    return Response([s.to_api_dict() for s in sales[:100]])


@api_view(["GET"])
def sale_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    sale = get_object_or_404(
        Sale.objects.prefetch_related("items", "payments", "returns"), pk=pk, organization=org
    )
    data = sale.to_api_dict()
    data["payments"] = [p.to_api_dict() for p in sale.payments.all()]
    data["returns"] = [r.to_api_dict() for r in sale.returns.all()]
    return Response(data)


# ═══════════════════════════════════════════════════════════════════════════════
#  RETURNS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def return_item(request, pk):
    """Return items from a sale. Restores stock and optionally refunds wallet."""
    request.throttle_scope = 'checkout'
    org, err = require_org(request)
    if err:
        return err
    sale = get_object_or_404(Sale, pk=pk, organization=org)
    item_id = request.data.get("saleItemId")
    qty = Decimal(str(request.data.get("quantity", 0)))
    refund_method = request.data.get("refundMethod", "wallet")
    reason = request.data.get("reason", "")

    if qty <= 0:
        return Response(
            {"detail": "Quantity must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )

    sale_item = get_object_or_404(SaleItem, pk=item_id, sale=sale)

    remaining = sale_item.quantity - sale_item.return_qty
    if qty > remaining:
        return Response(
            {"detail": f"Can only return {remaining} more units"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    with transaction.atomic():
        # Calculate refund amount (proportional with discount)
        line_total = (sale_item.price * sale_item.quantity) - sale_item.discount
        unit_refund = (
            line_total / sale_item.quantity if sale_item.quantity > 0 else Decimal("0")
        )
        refund_amount = unit_refund * qty

        # Restore stock
        if sale_item.item:
            sale_item.item.stock += qty
            sale_item.item.save()

        # Update sale item
        sale_item.return_qty += qty
        if sale_item.return_qty >= sale_item.quantity:
            sale_item.returned = True
        sale_item.save()

        # Update dispensing log
        DispensingLog.objects.filter(
            sale=sale, item=sale_item.item, name=sale_item.name
        ).update(status="Returned" if sale_item.returned else "Partially Returned")

        # Create return record
        ret = ReturnRecord.objects.create(
            sale=sale,
            sale_item=sale_item,
            quantity=qty,
            amount=refund_amount,
            refund_method=refund_method,
            reason=reason,
            returned_by=request.user if request.user.is_authenticated else None,
        )

        # Refund
        if refund_method == "wallet" and sale.customer:
            sale.customer.wallet_balance = (
                Decimal(str(sale.customer.wallet_balance)) + refund_amount
            )
            sale.customer.save()
            WalletTransaction.objects.create(
                customer=sale.customer,
                txn_type="topup",
                amount=refund_amount,
                note=f"Return #{ret.id} from {sale.receipt_id}",
            )

        # Update sale status
        all_returned = all(si.returned for si in sale.items.all())
        any_returned = any(si.returned or si.return_qty > 0 for si in sale.items.all())
        sale.status = (
            "returned"
            if all_returned
            else ("partial_return" if any_returned else sale.status)
        )
        sale.save()

    return Response(
        {"detail": "Return processed", "refundAmount": float(refund_amount)},
        status=status.HTTP_200_OK,
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  PAYMENT REQUESTS (Dispenser -> Cashier workflow)
# ═══════════════════════════════════════════════════════════════════════════════


def _create_payment_request(request, org):
    """Shared logic: create a PaymentRequest from a DRF request."""
    items_data = request.data.get("items", [])
    customer_id = request.data.get("customerId")
    cashier_id = request.data.get("cashierId")
    payment_type = request.data.get("paymentType", "retail")
    patient_name = request.data.get("patientName", "") or request.data.get("buyerName", "")

    if not items_data:
        return Response({"detail": "No items"}, status=status.HTTP_400_BAD_REQUEST)

    total = Decimal("0")
    for i in items_data:
        try:
            total += Decimal(str(i.get("price", 0))) * Decimal(str(i.get("quantity", 1)))
        except (ValueError, TypeError, Exception):
            return Response(
                {"detail": "Invalid price or quantity value"},
                status=status.HTTP_400_BAD_REQUEST,
            )

    customer = None
    if customer_id:
        customer = Customer.objects.filter(pk=customer_id, organization=org).first()

    cashier = None
    if cashier_id:
        cashier = Cashier.objects.filter(pk=cashier_id, is_active=True, user__organization=org).first()

    pr = PaymentRequest.objects.create(
        organization=org,
        dispenser=request.user,
        cashier=cashier,
        customer=customer,
        payment_type=payment_type,
        total_amount=total,
        buyer_name=patient_name,
    )

    for i in items_data:
        item = None
        if i.get("itemId"):
            item = Item.objects.filter(pk=i["itemId"], organization=org).first()
        PaymentRequestItem.objects.create(
            payment_request=pr,
            item=item,
            item_name=i.get("name", item.name if item else ""),
            brand=i.get("brand", item.brand if item else ""),
            dosage_form=i.get("dosageForm", item.dosage_form if item else ""),
            unit=i.get("unit", item.unit if item else ""),
            quantity=Decimal(str(i.get("quantity", 1))),
            unit_price=Decimal(str(i.get("price", 0))),
        )

    cashiers = Cashier.objects.filter(is_active=True, user__organization=org)
    if cashier_id:
        cashiers = cashiers.filter(pk=cashier_id)
    for c in cashiers:
        Notification.objects.create(
            user=c.user,
            notif_type="payment_request",
            priority="high",
            title="New Payment Request",
            message=f"Payment request {pr.request_id} for \u20a6{total} from {request.user.phone_number}",
        )

    return Response(pr.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["POST"])
def send_to_cashier(request):
    """Dispenser sends cart to cashier for payment."""
    org, err = require_org(request)
    if err:
        return err
    return _create_payment_request(request, org)


@api_view(["GET", "POST"])
def payment_request_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == "POST":
        return _create_payment_request(request, org)

    status_filter = request.query_params.get("status", "")
    prs = PaymentRequest.objects.filter(organization=org).prefetch_related("items")
    if status_filter:
        prs = prs.filter(status=status_filter)
    return Response([p.to_api_dict() for p in prs[:50]])


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def accept_payment_request(request, pk):
    request.throttle_scope = 'payment_request'
    org, err = require_org(request)
    if err:
        return err
    pr = get_object_or_404(PaymentRequest, pk=pk, organization=org)
    # Idempotent: if already accepted, return current state as success.
    # This handles duplicate requests from double-taps or offline sync replays.
    if pr.status == "accepted":
        return Response(pr.to_api_dict())
    if pr.status != "pending":
        return Response(
            {"detail": f"Cannot accept a request that is already {pr.status}"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    pr.status = "accepted"
    pr.save()
    return Response(pr.to_api_dict())


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def reject_payment_request(request, pk):
    request.throttle_scope = 'payment_request'
    org, err = require_org(request)
    if err:
        return err
    pr = get_object_or_404(PaymentRequest, pk=pk, organization=org)
    # Idempotent: if already rejected, return current state as success.
    if pr.status == "rejected":
        return Response(pr.to_api_dict())
    if pr.status != "pending":
        return Response(
            {"detail": f"Cannot reject a request that is already {pr.status}"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    pr.status = "rejected"
    pr.save()
    return Response(pr.to_api_dict())


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def complete_payment_request(request, pk):
    """Cashier completes payment - creates a Sale from the payment request."""
    request.throttle_scope = 'payment_request'
    org, err = require_org(request)
    if err:
        return err
    get_object_or_404(PaymentRequest, pk=pk, organization=org)  # 404 check before lock

    payment = request.data.get("payment", {})
    payment_method = request.data.get("paymentMethod", "cash")

    with transaction.atomic():
        pr = get_object_or_404(
            PaymentRequest.objects.select_for_update().prefetch_related("items"),
            pk=pk,
            organization=org,
        )
        if pr.status not in ("pending", "accepted"):
            return Response(
                {"detail": f"Request is already {pr.status}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        completing_cashier = Cashier.objects.filter(user=request.user).first()
        dispenser_shift = (
            Shift.objects.filter(organization=org, staff=pr.dispenser, status=Shift.STATUS_OPEN).first()
            if pr.dispenser else None
        )

        wallet_amt = Decimal(str(payment.get("wallet", 0)))
        wallet_insufficient = bool(
            pr.customer and wallet_amt > 0
            and Decimal(str(pr.customer.wallet_balance)) < wallet_amt
        )

        # Same change-clamp as checkout: keep only the cash applied to the sale.
        cash_amt = Decimal(str(payment.get("cash", 0)))
        pos_amt = Decimal(str(payment.get("pos", 0)))
        transfer_amt = Decimal(str(payment.get("bankTransfer", 0)))
        change = (cash_amt + pos_amt + transfer_amt + wallet_amt) - pr.total_amount
        if change > 0:
            cash_amt = max(cash_amt - change, Decimal("0"))

        sale = Sale.objects.create(
            organization=org,
            customer=pr.customer,
            dispenser=pr.dispenser,
            cashier=completing_cashier or pr.cashier,
            shift=dispenser_shift,
            total_amount=pr.total_amount,
            status="credit" if wallet_insufficient else "completed",
            payment_cash=cash_amt,
            payment_pos=pos_amt,
            payment_transfer=transfer_amt,
            payment_wallet=wallet_amt,
            payment_method=payment_method,
            buyer_name=pr.buyer_name,
        )

        for pri in pr.items.all():
            if pri.item:
                locked_item = Item.objects.select_for_update().get(pk=pri.item.pk)
                locked_item.stock = max(0, locked_item.stock - pri.quantity)
                locked_item.save()

            SaleItem.objects.create(
                sale=sale,
                item=pri.item,
                name=pri.item_name,
                brand=pri.brand,
                dosage_form=pri.dosage_form,
                unit=pri.unit,
                quantity=pri.quantity,
                price=pri.unit_price,
                discount=pri.discount_amount,
            )
            DispensingLog.objects.create(
                user=pr.dispenser,
                sale=sale,
                item=pri.item,
                name=pri.item_name,
                brand=pri.brand,
                dosage_form=pri.dosage_form,
                unit=pri.unit,
                quantity=pri.quantity,
                amount=pri.unit_price * pri.quantity,
                discount_amount=pri.discount_amount,
            )

        if pr.customer and wallet_amt > 0:
            pr.customer.wallet_balance = (
                Decimal(str(pr.customer.wallet_balance)) - wallet_amt
            )
            pr.customer.save()
            WalletTransaction.objects.create(
                customer=pr.customer,
                txn_type="purchase",
                amount=wallet_amt,
                note=f"Sale #{sale.id}",
            )

        pr.status = "completed"
        pr.receipt = sale
        pr.save()

    return Response(sale.to_api_dict(), status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════════════════
#  DISPENSING LOG
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def dispensing_log_list(request):
    org, err = require_org(request)
    if err:
        return err
    logs = DispensingLog.objects.filter(sale__organization=org).select_related("user", "item")
    search = request.query_params.get("search", "").strip()
    date_from = request.query_params.get("from")
    date_to = request.query_params.get("to")
    branch_id_str = request.query_params.get("branch_id", "").strip()

    if search:
        logs = logs.filter(Q(name__icontains=search) | Q(brand__icontains=search))
    if date_from:
        logs = logs.filter(created_at__date__gte=date_from)
    if date_to:
        logs = logs.filter(created_at__date__lte=date_to)
    if branch_id_str and branch_id_str.isdigit() and int(branch_id_str) > 0:
        logs = logs.filter(sale__branch_id=int(branch_id_str))

    return Response([l.to_api_dict() for l in logs[:200]])


@api_view(["GET"])
def dispensing_stats(request):
    org, err = require_org(request)
    if err:
        return err
    today = timezone.localdate()
    branch_id_str = request.query_params.get("branch_id", "").strip()
    branch_filter = {}
    if branch_id_str and branch_id_str.isdigit() and int(branch_id_str) > 0:
        branch_filter['sale__branch_id'] = int(branch_id_str)
    daily = DispensingLog.objects.filter(
        sale__organization=org, created_at__date=today, **branch_filter
    ).aggregate(count=Sum("quantity"), revenue=Sum("amount"))
    monthly = DispensingLog.objects.filter(
        sale__organization=org,
        created_at__year=today.year,
        created_at__month=today.month,
        **branch_filter,
    ).aggregate(count=Sum("quantity"), revenue=Sum("amount"))
    return Response(
        {
            "daily": {
                "count": daily["count"] or 0,
                "revenue": float(daily["revenue"] or 0),
            },
            "monthly": {
                "count": monthly["count"] or 0,
                "revenue": float(monthly["revenue"] or 0),
            },
        }
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  EXPENSES
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def expense_category_list(request):
    if request.method == "GET":
        return Response([c.to_api_dict() for c in ExpenseCategory.objects.all()])
    name = (request.data.get("name") or "").strip()
    if not name:
        return Response({"detail": "name is required."}, status=status.HTTP_400_BAD_REQUEST)
    cat, _ = ExpenseCategory.objects.get_or_create(name=name)
    return Response(cat.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "POST"])
def expense_list(request):
    org, err = require_org(request)
    if err:
        return err
    if request.method == "GET":
        expenses = Expense.objects.filter(organization=org).select_related("category")
        date_from_raw = request.query_params.get("from")
        date_to_raw = request.query_params.get("to")
        try:
            date_from = _date.fromisoformat(date_from_raw) if date_from_raw else None
            date_to = _date.fromisoformat(date_to_raw) if date_to_raw else None
        except ValueError:
            return Response({"detail": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)
        if date_from:
            expenses = expenses.filter(date__gte=date_from)
        if date_to:
            expenses = expenses.filter(date__lte=date_to)
        return Response([e.to_api_dict() for e in expenses])

    data = request.data
    cat = get_object_or_404(ExpenseCategory, pk=data.get("category_id") or data.get("categoryId"))
    raw_date = data.get("date")
    try:
        expense_date = _date.fromisoformat(raw_date) if isinstance(raw_date, str) else (raw_date or timezone.localdate())
    except (ValueError, TypeError):
        expense_date = timezone.localdate()
    source = (data.get("payment_source") or data.get("paymentSource") or "cash").lower()
    if source not in ("cash", "other"):
        source = "cash"
    expense = Expense.objects.create(
        organization=org,
        category=cat,
        amount=data.get("amount", 0),
        description=data.get("description", ""),
        payment_source=source,
        date=expense_date,
        created_by=request.user if request.user.is_authenticated else None,
    )
    return Response(expense.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["PUT", "DELETE"])
def expense_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    expense = get_object_or_404(Expense, pk=pk, organization=org)
    if request.method == "DELETE":
        expense.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    data = request.data
    expense.amount = data.get("amount", expense.amount)
    expense.description = data.get("description", expense.description)
    expense.save()
    return Response(expense.to_api_dict())


@api_view(["GET"])
def monthly_report(request):
    """Monthly report with sales, expenses, net profit."""
    from pos.models import Sale as PosSale

    org, err = require_org(request)
    if err:
        return err

    today = timezone.localdate()
    month = int(request.query_params.get("month", today.month))
    year = int(request.query_params.get("year", today.year))

    sales_qs = PosSale.objects.filter(
        organization=org,
        created__year=year,
        created__month=month,
        status__in=["completed", "partial_return"],
    )

    sales_total = sales_qs.aggregate(t=Sum("total_amount"))["t"] or 0

    # Cost of goods sold — mirrors the profit_report logic in reports/views.py
    from django.db.models import FloatField
    cogs = (
        SaleItem.objects.filter(
            sale__in=sales_qs,
            item__isnull=False,
            item__cost__gt=0,
        ).aggregate(
            t=Sum(F("quantity") * F("item__cost"), output_field=FloatField())
        )["t"]
        or 0
    )
    # Fall back to 70 % estimate when no cost prices are recorded
    if cogs == 0 and sales_total > 0:
        cogs = float(sales_total) * 0.70

    expenses_total = (
        Expense.objects.filter(organization=org, date__year=year, date__month=month).aggregate(
            t=Sum("amount")
        )["t"]
        or 0
    )

    net_profit = float(sales_total) - float(cogs) - float(expenses_total)

    return Response(
        {
            "month": f"{year}-{month:02d}",
            "totalSales": float(sales_total),
            "totalExpenses": float(expenses_total),
            "netProfit": net_profit,
        }
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  SUPPLIERS & PROCUREMENT
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET", "POST"])
def supplier_list(request):
    org, err = require_org(request)
    if err:
        return err
    if request.method == "GET":
        search = request.query_params.get("search", "").strip()
        suppliers = Supplier.objects.filter(organization=org)
        if search:
            suppliers = suppliers.filter(name__icontains=search)
        return Response([s.to_api_dict() for s in suppliers])
    data = request.data
    supplier = Supplier.objects.create(
        organization=org,
        name=data.get("name", ""),
        phone=data.get("phone", ""),
        contact_info=data.get("contactInfo", ""),
    )
    return Response(supplier.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "DELETE"])
def supplier_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    supplier = get_object_or_404(Supplier, pk=pk, organization=org)
    if request.method == "GET":
        return Response(supplier.to_api_dict())
    if request.method == "DELETE":
        supplier.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    data = request.data
    supplier.name = data.get("name", supplier.name)
    supplier.phone = data.get("phone", supplier.phone)
    supplier.contact_info = data.get("contactInfo", supplier.contact_info)
    supplier.save()
    return Response(supplier.to_api_dict())


@api_view(["GET", "POST"])
def procurement_list(request):
    org, err = require_org(request)
    if err:
        return err
    if request.method == "GET":
        procs = Procurement.objects.filter(organization=org).select_related("supplier").prefetch_related("items")
        search = request.query_params.get("search", "").strip()
        if search:
            procs = procs.filter(
                Q(supplier__name__icontains=search)
                | Q(items__item_name__icontains=search)
            ).distinct()
        return Response([p.to_api_dict() for p in procs])

    data = request.data
    supplier = get_object_or_404(Supplier, pk=data.get("supplierId"), organization=org)
    items_data = data.get("items", [])

    with transaction.atomic():
        proc = Procurement.objects.create(
            organization=org,
            supplier=supplier,
            created_by=request.user if request.user.is_authenticated else None,
            status=data.get("status", "draft"),
        )
        total = Decimal("0")
        for i in items_data:
            pi = ProcurementItem.objects.create(
                procurement=proc,
                item_name=i.get("itemName", ""),
                dosage_form=i.get("dosageForm", ""),
                brand=i.get("brand", ""),
                unit=i.get("unit", "Pcs"),
                quantity=int(i.get("quantity", 1)),
                cost_price=Decimal(str(i.get("costPrice", 0))),
                markup=Decimal(str(i.get("markup", 0))),
                expiry_date=i.get("expiryDate"),
                barcode=i.get("barcode") or "",
            )
            total += pi.subtotal

        proc.total = total
        proc.save()

        # If completed, move items to the specified store inventory
        if proc.status == "completed":
            dest = data.get("destination", "retail")
            if dest not in ("retail", "wholesale"):
                dest = "retail"
            _procurement_to_inventory(proc, destination=dest, org=org)

    return Response(proc.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def complete_procurement(request, pk):
    """Mark procurement as completed and add items to inventory (retail or wholesale)."""
    request.throttle_scope = 'procurement'
    org, err = require_org(request)
    if err:
        return err
    proc = get_object_or_404(Procurement.objects.prefetch_related("items"), pk=pk, organization=org)
    if proc.status == "completed":
        return Response(
            {"detail": "Already completed"}, status=status.HTTP_400_BAD_REQUEST
        )
    destination = request.data.get("destination", "retail")
    if destination not in ("retail", "wholesale"):
        destination = "retail"

    with transaction.atomic():
        proc.status = "completed"
        proc.save()
        _procurement_to_inventory(proc, destination=destination, org=org)

    return Response(proc.to_api_dict())


def _procurement_to_inventory(proc, destination="retail", org=None):
    """Move procurement items into the specified store inventory (retail or wholesale)."""
    for pi in proc.items.all():
        # Try to match existing item in the same store
        item = Item.objects.filter(
            name__iexact=pi.item_name,
            brand__iexact=pi.brand,
            dosage_form=pi.dosage_form,
            store=destination,
            organization=org,
        ).first()

        if item:
            item.stock += pi.quantity
            if pi.cost_price:
                item.cost = pi.cost_price
            item.save()
        else:
            price = pi.cost_price + (pi.cost_price * pi.markup / Decimal("100"))
            Item.objects.create(
                organization=org,
                name=pi.item_name,
                brand=pi.brand,
                dosage_form=pi.dosage_form,
                unit=pi.unit,
                cost=pi.cost_price,
                price=price,
                markup=pi.markup,
                stock=pi.quantity,
                barcode=pi.barcode,
                expiry_date=pi.expiry_date,
                store=destination,
            )


# ═══════════════════════════════════════════════════════════════════════════════
#  STOCK CHECK
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET", "POST"])
def stock_check_list(request):
    org, err = require_org(request)
    if err:
        return err
    store_type = request.GET.get("store_type") or request.data.get("store_type") or "retail"
    if store_type not in ("retail", "wholesale"):
        store_type = "retail"
    if request.method == "GET":
        checks = StockCheck.objects.filter(organization=org, store_type=store_type)
        return Response([c.to_api_dict() for c in checks])
    check = StockCheck.objects.create(
        organization=org,
        created_by=request.user if request.user.is_authenticated else None,
        status="pending",
        store_type=store_type,
    )
    return Response(check.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "DELETE"])
def stock_check_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    check = get_object_or_404(StockCheck, pk=pk, organization=org)
    if request.method == "DELETE":
        check.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    return Response(check.to_api_dict())


@api_view(["POST"])
def stock_check_add_item(request, pk):
    org, err = require_org(request)
    if err:
        return err
    check = get_object_or_404(StockCheck, pk=pk, organization=org)
    item_id = request.data.get("item_id") or request.data.get("itemId")
    item = get_object_or_404(Item, pk=item_id, organization=org, store=check.store_type)
    sci, created = StockCheckItem.objects.get_or_create(
        stock_check=check, item=item, defaults={"expected_quantity": item.stock}
    )
    if not created:
        return Response(
            {"detail": "Item already in check"}, status=status.HTTP_400_BAD_REQUEST
        )
    check.status = "in_progress"
    check.save()
    return Response(sci.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["POST", "PATCH"])
def stock_check_update_item(request, pk, item_pk):
    org, err = require_org(request)
    if err:
        return err
    get_object_or_404(StockCheck, pk=pk, organization=org)
    sci = get_object_or_404(StockCheckItem, pk=item_pk, stock_check_id=pk)
    sci.actual_quantity = (
        request.data.get("actual_quantity")
        or request.data.get("actualQuantity")
        or sci.actual_quantity
    )
    sci.status = request.data.get("status", sci.status)
    sci.save()
    return Response(sci.to_api_dict())


@api_view(["POST"])
def stock_check_approve(request, pk):
    org, err = require_org(request)
    if err:
        return err
    check = get_object_or_404(StockCheck, pk=pk, organization=org)
    with transaction.atomic():
        for sci in check.items.all():
            if (
                sci.actual_quantity is not None
                and sci.actual_quantity != sci.expected_quantity
            ):
                sci.item.stock = sci.actual_quantity
                sci.item.save()
                sci.status = "adjusted"
                sci.save()
        check.status = "completed"
        check.approved_by = request.user if request.user.is_authenticated else None
        check.approved_at = timezone.now()
        check.save()
    return Response(check.to_api_dict())


@api_view(["POST"])
def stock_check_cancel(request, pk):
    """Cancel a stock check without applying any stock adjustments."""
    org, err = require_org(request)
    if err:
        return err
    check = get_object_or_404(StockCheck, pk=pk, organization=org)
    if check.status == "completed":
        return Response(
            {"detail": "Cannot cancel a completed stock check"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if check.status == "cancelled":
        return Response(
            {"detail": "Stock check already cancelled"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    check.status = "cancelled"
    check.save(update_fields=["status"])
    return Response(check.to_api_dict())


@api_view(["DELETE"])
def stock_check_delete(request, pk):
    org, err = require_org(request)
    if err:
        return err
    check = get_object_or_404(StockCheck, pk=pk, organization=org)
    check.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
def stock_check_report(request):
    """Aggregate report for completed stock checks."""
    org, err = require_org(request)
    if err:
        return err
    store_type = request.GET.get("store_type", "retail")
    if store_type not in ("retail", "wholesale"):
        store_type = "retail"

    all_checks = StockCheck.objects.filter(organization=org, store_type=store_type)
    completed = all_checks.filter(status="completed")

    total_items = 0
    total_discrepancies = 0
    total_adjusted = 0
    total_cost_difference = 0.0
    completed_list = []

    for c in completed.order_by("-date"):
        items = c.items.select_related("item").all()
        t = items.count()
        matched = items.filter(status="matched").count()
        discrepant = items.filter(status__in=["discrepant", "adjusted"]).count()
        adjusted = items.filter(status="adjusted").count()
        total_items += t
        total_discrepancies += discrepant
        total_adjusted += adjusted

        check_cost_diff = 0.0
        for ci in items:
            discrepancy = float((ci.actual_quantity or ci.expected_quantity) - ci.expected_quantity)
            unit_price = float(getattr(ci.item, "price", 0) or 0)
            check_cost_diff += discrepancy * unit_price
        total_cost_difference += check_cost_diff

        cb = c.created_by
        created_by_name = (
            (getattr(cb, "full_name", "") or getattr(cb, "phone_number", ""))
            if cb else ""
        )
        completed_list.append({
            "id": c.id,
            "createdAt": c.date.isoformat(),
            "createdBy": created_by_name,
            "storeType": c.store_type,
            "totalItems": t,
            "matchedItems": matched,
            "discrepantItems": discrepant,
            "adjustedItems": adjusted,
            "totalCostDifference": round(check_cost_diff, 2),
        })

    return Response({
        "summary": {
            "totalChecks": all_checks.count(),
            "completedChecks": completed.count(),
            "totalItemsChecked": total_items,
            "totalDiscrepancies": total_discrepancies,
            "totalAdjustments": total_adjusted,
            "totalCostDifference": round(total_cost_difference, 2),
        },
        "completedChecks": completed_list,
    })


# ═══════════════════════════════════════════════════════════════════════════════
#  CASHIERS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET", "POST"])
def cashier_list(request):
    org, err = require_org(request)
    if err:
        return err
    if request.method == "GET":
        return Response(
            [c.to_api_dict() for c in Cashier.objects.filter(is_active=True, user__organization=org)]
        )
    data = request.data
    user = get_object_or_404(PharmUser, pk=data.get("userId"), organization=org)
    cashier = Cashier.objects.create(
        user=user,
        name=data.get("name", user.phone_number),
        cashier_type=data.get("cashierType", "retail"),
    )
    return Response(cashier.to_api_dict(), status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════════════════
#  NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def notification_list(request):
    notifs = Notification.objects.filter(user=request.user).order_by("-created_at")[:50]
    return Response([n.to_api_dict() for n in notifs])


@api_view(["POST"])
def notification_read(request, pk):
    notif = get_object_or_404(Notification, pk=pk, user=request.user)
    notif.is_read = True
    notif.save()
    return Response(notif.to_api_dict())


@api_view(["GET"])
def notification_count(request):
    count = Notification.objects.filter(user=request.user, is_read=False).count()
    return Response({"count": count})


# ═══════════════════════════════════════════════════════════════════════════════
#  BARCODE SCANNING
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def barcode_lookup(request):
    org, err = require_org(request)
    if err:
        return err
    code = request.query_params.get("code", "").strip()
    if not code:
        return Response(
            {"detail": "No barcode provided"}, status=status.HTTP_400_BAD_REQUEST
        )

    # Try exact barcode match
    item = Item.objects.filter(barcode=code, organization=org).first()
    if item:
        return Response(item.to_api_dict())

    # Try GTIN match
    item = Item.objects.filter(gtin=code, organization=org).first()
    if item:
        return Response(item.to_api_dict())

    # Try partial GTIN (without leading zeros)
    item = Item.objects.filter(gtin__endswith=code.lstrip("0"), organization=org).first()
    if item:
        return Response(item.to_api_dict())

    return Response({"detail": "Item not found"}, status=status.HTTP_404_NOT_FOUND)


# ═══════════════════════════════════════════════════════════════════════════════
#  USER MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════


def _is_admin_or_manager(user):
    return getattr(user, "role", "") in ("Admin", "Manager")


@api_view(["GET", "POST"])
def user_list(request):
    if not _is_admin_or_manager(request.user):
        return Response({"detail": "Admin or Manager access required"}, status=status.HTTP_403_FORBIDDEN)
    org, err = require_org(request)
    if err:
        return err

    if request.method == "GET":
        users = PharmUser.objects.filter(organization=org)
        search = request.query_params.get("search", "").strip()
        role = request.query_params.get("role", "").strip()
        if search:
            from django.db.models import Q
            users = users.filter(Q(phone_number__icontains=search) | Q(full_name__icontains=search))
        if role:
            users = users.filter(role=role)
        return Response([u.to_api_dict() for u in users])

    data = request.data
    phone = data.get("phoneNumber", "").strip()
    password = data.get("password", "").strip()
    role = data.get("role", "Cashier")
    full_name = data.get("username", "").strip()

    if not phone or not password:
        return Response(
            {"detail": "Phone and password required"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    phone = normalize_ng_phone(phone)
    if phone is None:
        return Response(
            {"detail": "Enter a valid Nigerian mobile number "
                       "(e.g. 08012345678 or +2348012345678)."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if PharmUser.objects.filter(
        phone_number__in=[phone, '+234' + phone[1:], '234' + phone[1:]]
    ).exists():
        return Response(
            {"detail": "Phone already registered"}, status=status.HTTP_400_BAD_REQUEST
        )

    user = PharmUser.objects.create_user(
        phone_number=phone, password=password, role=role, organization=org,
        full_name=full_name,
    )
    return Response(user.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
def user_detail(request, pk):
    if not _is_admin_or_manager(request.user):
        return Response({"detail": "Admin or Manager access required"}, status=status.HTTP_403_FORBIDDEN)
    org, err = require_org(request)
    if err:
        return err
    user = get_object_or_404(PharmUser, pk=pk, organization=org)
    if request.method == "GET":
        return Response(user.to_api_dict())
    if request.method == "DELETE":
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    data = request.data
    if "phoneNumber" in data and data["phoneNumber"].strip():
        new_phone = normalize_ng_phone(data["phoneNumber"])
        if new_phone is None:
            return Response(
                {"detail": "Enter a valid Nigerian mobile number "
                           "(e.g. 08012345678 or +2348012345678)."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.phone_number = new_phone
    user.role = data.get("role", user.role)
    user.is_active = data.get("isActive", user.is_active)
    if "username" in data:
        user.full_name = data["username"].strip()
    if "branch_id" in data:
        branch_id = data["branch_id"]
        user.branch_id = branch_id if branch_id else None
    user.save()
    return Response(user.to_api_dict())


@api_view(["POST"])
def change_password(request, pk):
    if not _is_admin_or_manager(request.user):
        return Response({"detail": "Admin or Manager access required"}, status=status.HTTP_403_FORBIDDEN)
    org, err = require_org(request)
    if err:
        return err
    user = get_object_or_404(PharmUser, pk=pk, organization=org)
    new_password = request.data.get("newPassword", "").strip()
    if len(new_password) < 8:
        return Response(
            {"detail": "Password must be at least 8 characters."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not re.search(r'[A-Za-z]', new_password) or not re.search(r'\d', new_password):
        return Response(
            {"detail": "Password must contain at least one letter and one digit."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    user.set_password(new_password)
    user.save()
    return Response({"detail": "Password changed"})


# ── Shifts ────────────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def shift_list(request):
    """GET /pos/shifts/ — list shifts for org, optionally filtered."""
    org, err = require_org(request)
    if err:
        return err

    from datetime import date
    qs = Shift.objects.filter(organization=org).select_related('staff', 'branch')

    # Non-senior staff see only their own shifts.
    if getattr(request.user, 'role', '') not in REPORTS_ROLES:
        qs = qs.filter(staff=request.user)

    from_date = request.query_params.get('from')
    to_date   = request.query_params.get('to')
    staff_id  = request.query_params.get('staff_id')
    branch_id = request.query_params.get('branch_id')

    if from_date:
        try:
            qs = qs.filter(opened_at__date__gte=date.fromisoformat(from_date))
        except ValueError:
            pass
    if to_date:
        try:
            qs = qs.filter(opened_at__date__lte=date.fromisoformat(to_date))
        except ValueError:
            pass
    if staff_id:
        qs = qs.filter(staff_id=staff_id)
    if branch_id:
        qs = qs.filter(branch_id=branch_id)

    return Response([s.to_api_dict() for s in qs[:200]])


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def shift_current(request):
    """GET /pos/shifts/current/ — the caller's currently open shift, or 204."""
    org, err = require_org(request)
    if err:
        return err
    shift = Shift.objects.filter(
        organization=org, staff=request.user, status=Shift.STATUS_OPEN
    ).first()
    if not shift:
        return Response(status=204)
    return Response(shift.to_api_dict())


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def shift_open(request):
    """POST /pos/shifts/open/ — open a new shift (one open shift per user)."""
    org, err = require_org(request)
    if err:
        return err

    # Prevent double-open
    if Shift.objects.filter(organization=org, staff=request.user, status=Shift.STATUS_OPEN).exists():
        return Response({"detail": "You already have an open shift."}, status=400)

    branch_id    = request.data.get('branch_id')
    opening_cash = request.data.get('opening_cash', 0)
    try:
        opening_cash = float(opening_cash)
    except (TypeError, ValueError):
        opening_cash = 0.0

    from branches.models import Branch
    branch = Branch.objects.filter(pk=branch_id, organization=org).first() if branch_id else None

    shift = Shift.objects.create(
        organization=org,
        staff=request.user,
        branch=branch,
        opening_cash=opening_cash,
        status=Shift.STATUS_OPEN,
    )
    log_activity(request, action='Open Shift', category='pos',
                 description=f'Shift #{shift.id} opened with ₦{opening_cash:,.0f} opening cash')
    return Response(shift.to_api_dict(), status=201)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def shift_close(request, pk):
    """POST /pos/shifts/<pk>/close/ — close a shift."""
    org, err = require_org(request)
    if err:
        return err

    shift = Shift.objects.filter(pk=pk, organization=org, staff=request.user).first()
    if not shift:
        return Response({"detail": "Shift not found."}, status=404)
    if shift.status == Shift.STATUS_CLOSED:
        return Response({"detail": "Shift is already closed."}, status=400)

    closing_cash = request.data.get('closing_cash', 0)
    try:
        closing_cash = float(closing_cash)
    except (TypeError, ValueError):
        closing_cash = 0.0

    from django.utils import timezone as tz
    shift.status       = Shift.STATUS_CLOSED
    shift.closed_at    = tz.now()
    shift.closing_cash = closing_cash
    shift.save()

    log_activity(request, action='Close Shift', category='pos',
                 description=f'Shift #{shift.id} closed with ₦{closing_cash:,.0f} closing cash')
    return Response(shift.to_api_dict())


# ── SMS Alerts ────────────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_sms(request):
    """
    POST /pos/send-sms/
    Body: { customer_id, message, template? }
    Sends an SMS to the customer's phone number.
    Requires SMS_PROVIDER_URL + SMS_API_KEY in settings (optional).
    Falls back to logging if not configured.
    """
    org, err = require_org(request)
    if err:
        return err

    from customers.models import Customer as _Customer
    customer_id = request.data.get('customer_id')
    message     = (request.data.get('message') or '').strip()
    template    = request.data.get('template', 'custom')

    if not customer_id:
        return Response({"detail": "customer_id is required."}, status=400)
    if not message:
        return Response({"detail": "message is required."}, status=400)

    customer = _Customer.objects.filter(pk=customer_id, organization=org).first()
    if not customer:
        return Response({"detail": "Customer not found."}, status=404)

    phone = customer.phone.strip()
    if not phone:
        return Response({"detail": "Customer has no phone number."}, status=400)

    # Normalize phone to international format (Nigeria: 0XXXXXXXXXX → +234XXXXXXXXXX)
    if phone.startswith('0') and len(phone) == 11:
        phone = '+234' + phone[1:]
    elif not phone.startswith('+'):
        phone = '+234' + phone

    import logging
    logger = logging.getLogger('pharmapp.sms')

    from django.conf import settings as djsettings
    sms_url = getattr(djsettings, 'SMS_PROVIDER_URL', None)
    sms_key = getattr(djsettings, 'SMS_API_KEY', None)
    sender  = getattr(djsettings, 'SMS_SENDER_ID', 'PharmApp')

    if sms_url and sms_key:
        import requests as _requests
        try:
            resp = _requests.post(sms_url, json={
                'to':      phone,
                'from':    sender,
                'sms':     message,
                'type':    'plain',
                'api_key': sms_key,
                'channel': 'generic',
            }, timeout=10)
            if resp.status_code not in (200, 201):
                logger.warning("SMS send failed: %s %s", resp.status_code, resp.text)
                return Response({"detail": f"SMS provider error: {resp.text}"}, status=502)
        except Exception as exc:
            logger.error("SMS exception: %s", exc)
            return Response({"detail": "SMS provider unreachable."}, status=502)
    else:
        # No SMS config — log and return success (dev/staging fallback)
        logger.info("SMS (no provider configured) → %s: %s", phone, message)

    log_activity(request, action='Send SMS', category='customers',
                 description=f'SMS ({template}) sent to {customer.name} ({phone})')

    # Optionally create an in-app notification for the customer's user (if linked)
    Notification.objects.create(
        user=request.user,
        notif_type='system',
        priority='low',
        title=f'SMS sent to {customer.name}',
        message=message[:200],
    )

    return Response({"detail": "SMS sent.", "phone": phone})
