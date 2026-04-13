"""Wholesale-specific API views."""

from decimal import Decimal
from django.db import transaction
from django.db.models import Sum, Count, F, Q, DecimalField, ExpressionWrapper
from django.utils import timezone
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from inventory.models import Item
from customers.models import Customer
from .models import Sale, SaleItem, TransferRequest, ReturnRecord, DispensingLog
from authapp.utils import require_org
from authapp.permissions import require_role, TRANSFERS_ROLES


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_dashboard(request):
    org, err = require_org(request)
    if err:
        return err

    today = timezone.now().date()
    sales = Sale.objects.filter(organization=org, is_wholesale=True)
    today_sales = sales.filter(created__date=today)

    revenue_today = float(today_sales.aggregate(t=Sum("total_amount"))["t"] or 0)
    total_sales = sales.count()
    today_count = today_sales.count()
    units_today = (
        SaleItem.objects.filter(sale__in=today_sales).aggregate(t=Sum("quantity"))["t"]
        or 0
    )

    ws_customers = Customer.objects.filter(organization=org, is_wholesale=True)
    total_ws_customers = ws_customers.count()
    ws_debt = float(ws_customers.aggregate(t=Sum("outstanding_debt"))["t"] or 0)

    low_stock = Item.objects.filter(
        organization=org, store="wholesale", stock__lte=F("low_stock_threshold")
    ).order_by("stock")[:5]

    top_products = (
        SaleItem.objects.filter(
            sale__in=today_sales, item__isnull=False, item__store="wholesale"
        )
        .values("item__name")
        .annotate(
            qty=Sum("quantity"),
            rev=Sum(
                ExpressionWrapper(
                    F("quantity") * F("price"), output_field=DecimalField()
                )
            ),
        )
        .order_by("-qty")[:5]
    )

    recent_transfers = TransferRequest.objects.filter(
        organization=org, from_wholesale=True, status="pending"
    ).select_related("requested_by")[:5]

    return Response(
        {
            "todayRevenue": revenue_today,
            "revenueToday": revenue_today,  # legacy alias
            "totalSales": total_sales,
            "salesToday": today_count,
            "unitsSold": int(units_today),
            "unitsSoldToday": int(units_today),  # legacy alias
            "wholesaleCustomers": total_ws_customers,
            "outstandingDebt": ws_debt,
            "wholesaleDebt": ws_debt,  # legacy alias
            "lowStockItems": [
                {"name": i.name, "stock": i.stock, "threshold": i.low_stock_threshold}
                for i in low_stock
            ],
            "topProducts": [
                {
                    "name": r["item__name"],
                    "qty": r["qty"],
                    "revenue": float(r["rev"] or 0),
                }
                for r in top_products
            ],
            "pendingTransfers": [t.to_api_dict() for t in recent_transfers],
        }
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE CUSTOMERS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_customer_list(request):
    org, err = require_org(request)
    if err:
        return err
    customers = Customer.objects.filter(organization=org, is_wholesale=True).order_by(
        "name"
    )
    search = request.query_params.get("search", "").strip()
    if search:
        customers = customers.filter(
            Q(name__icontains=search) | Q(phone__icontains=search)
        )
    return Response([c.to_list_dict() for c in customers])


@api_view(["GET"])
def wholesale_customer_negative(request):
    """Customers with negative wallet balance (debt)."""
    org, err = require_org(request)
    if err:
        return err
    customers = Customer.objects.filter(
        organization=org, is_wholesale=True, outstanding_debt__gt=0
    ).order_by("-outstanding_debt")
    return Response([c.to_list_dict() for c in customers])


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE SALES / RECEIPTS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_sale_list(request):
    org, err = require_org(request)
    if err:
        return err
    sales = (
        Sale.objects.filter(organization=org, is_wholesale=True)
        .select_related("customer", "cashier")
        .order_by("-created")
    )
    date_from = request.query_params.get("from")
    date_to = request.query_params.get("to")
    search = request.query_params.get("search", "").strip()
    if date_from:
        sales = sales.filter(created__date__gte=date_from)
    if date_to:
        sales = sales.filter(created__date__lte=date_to)
    if search:
        sales = sales.filter(
            Q(receipt_id__icontains=search)
            | Q(customer__name__icontains=search)
            | Q(buyer_name__icontains=search)
        )
    return Response([s.to_api_dict() for s in sales[:100]])


@api_view(["GET"])
def wholesale_sale_by_user(request):
    """Sales aggregated by user (dispenser)."""
    org, err = require_org(request)
    if err:
        return err

    today = timezone.now().date()
    date_from = request.query_params.get("from", today.isoformat())
    date_to = request.query_params.get("to", today.isoformat())

    rows = (
        Sale.objects.filter(
            organization=org,
            is_wholesale=True,
            created__date__gte=date_from,
            created__date__lte=date_to,
        )
        .values("dispenser__phone_number", "dispenser__full_name")
        .annotate(
            total_sales=Count("id"),
            total_amount=Sum("total_amount"),
        )
        .order_by("-total_amount")
    )

    return Response(
        [
            {
                "userName": r["dispenser__full_name"] or r["dispenser__phone_number"] or "Unknown",
                "user": r["dispenser__full_name"] or r["dispenser__phone_number"] or "Unknown",
                "totalSales": r["total_sales"] or 0,
                "totalAmount": float(r["total_amount"] or 0),
            }
            for r in rows
        ]
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  TRANSFERS (Wholesale ↔ Retail)
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET", "POST"])
def transfer_list(request):
    org, err = require_org(request)
    if err:
        return err

    err = require_role(request, TRANSFERS_ROLES)
    if err:
        return err

    if request.method == "GET":
        transfers = (
            TransferRequest.objects.filter(organization=org)
            .select_related("requested_by")
            .order_by("-created_at")
        )
        status_filter = request.query_params.get("status", "")
        if status_filter:
            transfers = transfers.filter(status=status_filter)
        direction = request.query_params.get("direction", "")
        if direction == "outgoing":
            transfers = transfers.filter(from_wholesale=True)
        elif direction == "incoming":
            transfers = transfers.filter(from_wholesale=False)
        return Response([t.to_api_dict() for t in transfers])

    data = request.data
    transfer = TransferRequest.objects.create(
        organization=org,
        from_wholesale=data.get("fromWholesale", True),
        item_name=data.get("itemName", ""),
        requested_quantity=Decimal(str(data.get("requestedQty", 0))),
        unit=data.get("unit", "Pcs"),
        notes=data.get("notes", ""),
        requested_by=request.user if request.user.is_authenticated else None,
    )
    return Response(transfer.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET"])
def transfer_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err

    err = require_role(request, TRANSFERS_ROLES)
    if err:
        return err

    transfer = get_object_or_404(
        TransferRequest.objects.select_related("requested_by"), pk=pk, organization=org
    )
    return Response(transfer.to_api_dict())


@api_view(["POST"])
def transfer_approve(request, pk):
    org, err = require_org(request)
    if err:
        return err

    err = require_role(request, TRANSFERS_ROLES)
    if err:
        return err

    transfer = get_object_or_404(TransferRequest, pk=pk, organization=org)
    if transfer.status != "pending":
        return Response(
            {"detail": f"Already {transfer.status}"}, status=status.HTTP_400_BAD_REQUEST
        )

    src_store = "wholesale" if transfer.from_wholesale else "retail"
    approved_qty = Decimal(str(request.data.get("approvedQty", transfer.requested_quantity)))

    # Warn if approving more than source stock
    src_item = Item.objects.filter(
        organization=org, name__iexact=transfer.item_name, store=src_store
    ).first()
    if src_item is None:
        return Response(
            {"detail": f"Item '{transfer.item_name}' not found in {src_store} store."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if approved_qty > src_item.stock:
        return Response(
            {
                "detail": f"Insufficient stock: only {src_item.stock} available in {src_store}."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    transfer.status = "approved"
    transfer.approved_quantity = approved_qty
    transfer.approved_by = request.user if request.user.is_authenticated else None
    transfer.save()
    return Response(transfer.to_api_dict())


@api_view(["POST"])
def transfer_reject(request, pk):
    org, err = require_org(request)
    if err:
        return err

    err = require_role(request, TRANSFERS_ROLES)
    if err:
        return err

    transfer = get_object_or_404(TransferRequest, pk=pk, organization=org)
    if transfer.status != "pending":
        return Response(
            {"detail": f"Already {transfer.status}"}, status=status.HTTP_400_BAD_REQUEST
        )
    transfer.status = "rejected"
    transfer.save()
    return Response(transfer.to_api_dict())


@api_view(["POST"])
def transfer_receive(request, pk):
    org, err = require_org(request)
    if err:
        return err

    err = require_role(request, TRANSFERS_ROLES)
    if err:
        return err

    transfer = get_object_or_404(TransferRequest, pk=pk, organization=org)
    if transfer.status != "approved":
        return Response(
            {"detail": "Must be approved first"}, status=status.HTTP_400_BAD_REQUEST
        )

    qty = transfer.approved_quantity
    if transfer.from_wholesale:
        # Wholesale → Retail: deduct from wholesale, add to retail
        src_store, dst_store = "wholesale", "retail"
    else:
        # Retail → Wholesale: deduct from retail, add to wholesale
        src_store, dst_store = "retail", "wholesale"

    # Validate source item and stock BEFORE entering the atomic block so that
    # a validation failure does not accidentally commit a status change.
    src_item = Item.objects.filter(
        organization=org, name__iexact=transfer.item_name, store=src_store
    ).first()
    if src_item is None:
        return Response(
            {
                "detail": f"Source item '{transfer.item_name}' not found in {src_store} store."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )
    if qty > src_item.stock:
        return Response(
            {
                "detail": f"Insufficient stock: only {src_item.stock} available in {src_store}."
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    with transaction.atomic():
        transfer.status = "received"
        transfer.save()

        dst_item = Item.objects.filter(
            organization=org, name__iexact=transfer.item_name, store=dst_store
        ).first()

        # If destination store doesn't carry this item yet, create it
        if dst_item is None:
            dst_item = Item.objects.create(
                organization=org,
                name=src_item.name,
                brand=src_item.brand,
                dosage_form=src_item.dosage_form,
                unit=src_item.unit,
                cost=src_item.cost,
                price=src_item.price,
                markup=src_item.markup,
                low_stock_threshold=src_item.low_stock_threshold,
                store=dst_store,
                stock=0,
            )

        src_item.stock -= qty
        src_item.save()

        dst_item.stock += qty
        dst_item.save()

    return Response(transfer.to_api_dict())


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE INVENTORY
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_low_stock(request):
    org, err = require_org(request)
    if err:
        return err
    items = Item.objects.filter(
        organization=org, store="wholesale", stock__lte=F("low_stock_threshold")
    ).order_by("stock")
    search = request.query_params.get("search", "").strip()
    if search:
        items = items.filter(Q(name__icontains=search) | Q(brand__icontains=search))
    return Response([i.to_api_dict() for i in items])


@api_view(["GET"])
def wholesale_expiry_alert(request):
    org, err = require_org(request)
    if err:
        return err
    today = timezone.now().date()
    items = Item.objects.filter(
        organization=org,
        store="wholesale",
        expiry_date__isnull=False,
        expiry_date__lte=today + timezone.timedelta(days=90),
        stock__gt=0,
    ).order_by("expiry_date")
    return Response(
        [
            {
                **i.to_api_dict(),
                "expired": i.expiry_date < today,
                "daysLeft": (i.expiry_date - today).days,
            }
            for i in items
        ]
    )


@api_view(["GET"])
def wholesale_sale_detail(request, pk):
    """Detail of a single wholesale sale including items, payments, and returns."""
    org, err = require_org(request)
    if err:
        return err
    sale = get_object_or_404(
        Sale.objects.prefetch_related("items", "payments", "returns"),
        pk=pk,
        organization=org,
        is_wholesale=True,
    )
    data = sale.to_api_dict()
    data["payments"] = [p.to_api_dict() for p in sale.payments.all()]
    data["returns"] = [r.to_api_dict() for r in sale.returns.all()]
    return Response(data)


@api_view(["POST"])
def wholesale_sale_return(request, pk):
    """Return items from a wholesale sale. Restores stock and optionally refunds wallet."""
    org, err = require_org(request)
    if err:
        return err
    sale = get_object_or_404(Sale, pk=pk, organization=org, is_wholesale=True)
    item_id = request.data.get("saleItemId")
    qty = int(request.data.get("quantity", 0))
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
        line_total = (sale_item.price * sale_item.quantity) - sale_item.discount
        unit_refund = (
            line_total / sale_item.quantity if sale_item.quantity > 0 else Decimal("0")
        )
        refund_amount = unit_refund * qty

        if sale_item.item:
            sale_item.item.stock += qty
            sale_item.item.save()

        sale_item.return_qty += qty
        if sale_item.return_qty >= sale_item.quantity:
            sale_item.returned = True
        sale_item.save()

        DispensingLog.objects.filter(
            sale=sale, item=sale_item.item, name=sale_item.name
        ).update(status="Returned" if sale_item.returned else "Partially Returned")

        ReturnRecord.objects.create(
            sale=sale,
            sale_item=sale_item,
            quantity=qty,
            amount=refund_amount,
            refund_method=refund_method,
            reason=reason,
            returned_by=request.user if request.user.is_authenticated else None,
        )

        if refund_method == "wallet" and sale.customer:
            from customers.models import WalletTransaction

            sale.customer.wallet_balance = (
                Decimal(str(sale.customer.wallet_balance)) + refund_amount
            )
            sale.customer.save()
            WalletTransaction.objects.create(
                customer=sale.customer,
                txn_type="topup",
                amount=refund_amount,
                note=f"Refund for wholesale return - Receipt {sale.receipt_id}",
            )

        sale.refresh_from_db()
        all_returned = all(i.returned for i in sale.items.all())
        if all_returned:
            sale.status = "returned"
        elif sale.returns.count() > 0:
            sale.status = "partial_return"
        sale.save()

    sale.refresh_from_db()
    data = sale.to_api_dict()
    data["payments"] = [p.to_api_dict() for p in sale.payments.all()]
    data["returns"] = [r.to_api_dict() for r in sale.returns.all()]
    return Response(data)


@api_view(["GET"])
def wholesale_inventory_value(request):
    org, err = require_org(request)
    if err:
        return err
    result = Item.objects.filter(organization=org, store="wholesale").aggregate(
        total_purchase_value=Sum(
            ExpressionWrapper(F("cost") * F("stock"), output_field=DecimalField())
        ),
        total_stock_value=Sum(
            ExpressionWrapper(F("price") * F("stock"), output_field=DecimalField())
        ),
        total_items=Count("id"),
    )
    purchase = float(result["total_purchase_value"] or 0)
    stock_val = float(result["total_stock_value"] or 0)
    return Response(
        {
            "totalPurchaseValue": purchase,
            "totalStockValue": stock_val,
            "potentialProfit": stock_val - purchase,
            "totalItems": result["total_items"] or 0,
        }
    )
