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
from .models import Sale, SaleItem, TransferRequest


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_dashboard(request):
    today = timezone.now().date()
    sales = Sale.objects.filter(is_wholesale=True)
    today_sales = sales.filter(created__date=today)

    revenue_today = float(today_sales.aggregate(t=Sum("total_amount"))["t"] or 0)
    total_sales = sales.count()
    today_count = today_sales.count()
    units_today = (
        SaleItem.objects.filter(sale__in=today_sales).aggregate(t=Sum("quantity"))["t"]
        or 0
    )

    ws_customers = Customer.objects.filter(is_wholesale=True)
    total_ws_customers = ws_customers.count()
    ws_debt = float(ws_customers.aggregate(t=Sum("outstanding_debt"))["t"] or 0)

    low_stock = Item.objects.filter(stock__lte=F("low_stock_threshold")).order_by(
        "stock"
    )[:5]

    top_products = (
        SaleItem.objects.filter(sale__in=today_sales, item__isnull=False)
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
        from_wholesale=True, status="pending"
    )[:5]

    return Response(
        {
            "revenueToday": revenue_today,
            "totalSales": total_sales,
            "salesToday": today_count,
            "unitsSoldToday": int(units_today),
            "wholesaleCustomers": total_ws_customers,
            "wholesaleDebt": ws_debt,
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
    customers = Customer.objects.filter(is_wholesale=True).order_by("name")
    search = request.query_params.get("search", "").strip()
    if search:
        customers = customers.filter(
            Q(name__icontains=search) | Q(phone__icontains=search)
        )
    return Response([c.to_list_dict() for c in customers])


@api_view(["GET"])
def wholesale_customer_negative(request):
    """Customers with negative wallet balance (debt)."""
    customers = Customer.objects.filter(
        is_wholesale=True, outstanding_debt__gt=0
    ).order_by("-outstanding_debt")
    return Response([c.to_list_dict() for c in customers])


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE SALES / RECEIPTS
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_sale_list(request):
    sales = (
        Sale.objects.filter(is_wholesale=True)
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
    from pos.models import DispensingLog

    today = timezone.now().date()
    date_from = request.query_params.get("from", today.isoformat())
    date_to = request.query_params.get("to", today.isoformat())

    logs = (
        DispensingLog.objects.filter(
            created_at__date__gte=date_from,
            created_at__date__lte=date_to,
            sale__is_wholesale=True,
        )
        .values("user__phone_number")
        .annotate(total_items=Sum("quantity"), total_amount=Sum("amount"))
        .order_by("-total_amount")
    )

    return Response(
        [
            {
                "user": r["user__phone_number"] or "Unknown",
                "totalItems": r["total_items"] or 0,
                "totalAmount": float(r["total_amount"] or 0),
            }
            for r in logs
        ]
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  TRANSFERS (Wholesale ↔ Retail)
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET", "POST"])
def transfer_list(request):
    if request.method == "GET":
        transfers = TransferRequest.objects.all().order_by("-created_at")
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
        from_wholesale=data.get("fromWholesale", True),
        item_name=data.get("itemName", ""),
        requested_quantity=int(data.get("requestedQty", 0)),
        unit=data.get("unit", "Pcs"),
        notes=data.get("notes", ""),
        requested_by=request.user if request.user.is_authenticated else None,
    )
    return Response(transfer.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET"])
def transfer_detail(request, pk):
    transfer = get_object_or_404(TransferRequest, pk=pk)
    return Response(transfer.to_api_dict())


@api_view(["POST"])
def transfer_approve(request, pk):
    transfer = get_object_or_404(TransferRequest, pk=pk)
    if transfer.status != "pending":
        return Response(
            {"detail": f"Already {transfer.status}"}, status=status.HTTP_400_BAD_REQUEST
        )
    transfer.status = "approved"
    transfer.approved_quantity = int(
        request.data.get("approvedQty", transfer.requested_quantity)
    )
    transfer.approved_by = request.user if request.user.is_authenticated else None
    transfer.save()
    return Response(transfer.to_api_dict())


@api_view(["POST"])
def transfer_reject(request, pk):
    transfer = get_object_or_404(TransferRequest, pk=pk)
    if transfer.status != "pending":
        return Response(
            {"detail": f"Already {transfer.status}"}, status=status.HTTP_400_BAD_REQUEST
        )
    transfer.status = "rejected"
    transfer.save()
    return Response(transfer.to_api_dict())


@api_view(["POST"])
def transfer_receive(request, pk):
    transfer = get_object_or_404(TransferRequest, pk=pk)
    if transfer.status != "approved":
        return Response(
            {"detail": "Must be approved first"}, status=status.HTTP_400_BAD_REQUEST
        )

    with transaction.atomic():
        transfer.status = "received"
        transfer.save()
        # Update stock
        item = Item.objects.filter(name__iexact=transfer.item_name).first()
        if item:
            if transfer.from_wholesale:
                item.stock = max(0, item.stock - transfer.approved_quantity)
            else:
                item.stock += transfer.approved_quantity
            item.save()

    return Response(transfer.to_api_dict())


# ═══════════════════════════════════════════════════════════════════════════════
#  WHOLESALE INVENTORY
# ═══════════════════════════════════════════════════════════════════════════════


@api_view(["GET"])
def wholesale_low_stock(request):
    items = Item.objects.filter(stock__lte=F("low_stock_threshold")).order_by("stock")
    search = request.query_params.get("search", "").strip()
    if search:
        items = items.filter(Q(name__icontains=search) | Q(brand__icontains=search))
    return Response([i.to_api_dict() for i in items])


@api_view(["GET"])
def wholesale_expiry_alert(request):
    today = timezone.now().date()
    items = Item.objects.filter(
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
def wholesale_inventory_value(request):
    result = Item.objects.aggregate(
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
