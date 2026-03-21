from datetime import date, timedelta
from django.db import models as db_models
from django.db.models import F
from rest_framework.decorators import api_view
from rest_framework.response import Response
from inventory.models import Item
from customers.models import Customer
from pos.models import Sale, SaleItem


def _date_range(period):
    today = date.today()
    if period == "today":
        return today, today
    if period == "week":
        return today - timedelta(days=7), today
    if period == "month":
        return today - timedelta(days=30), today
    if period == "quarter":
        return today - timedelta(days=90), today
    if period == "year":
        return today - timedelta(days=365), today
    return today - timedelta(days=30), today


@api_view(["GET"])
def sales_report(request):
    period = request.query_params.get("period", "month")
    start, end = _date_range(period)

    sales = Sale.objects.filter(created__date__gte=start, created__date__lte=end)

    retail_sales = sales.filter(is_wholesale=False)
    wholesale_sales = sales.filter(is_wholesale=True)

    total_retail = float(
        retail_sales.aggregate(t=db_models.Sum("total_amount"))["t"] or 0
    )
    total_wholesale = float(
        wholesale_sales.aggregate(t=db_models.Sum("total_amount"))["t"] or 0
    )
    total_revenue = total_retail + total_wholesale

    # Top items by qty sold
    top_items_qs = (
        SaleItem.objects.filter(sale__in=sales)
        .values("item__id", "item__name")
        .annotate(
            qty=db_models.Sum("quantity"),
            revenue=db_models.Sum(
                db_models.F("quantity") * db_models.F("price"),
                output_field=db_models.FloatField(),
            ),
        )
        .order_by("-qty")[:10]
    )

    top_items = [
        {
            "itemId": r["item__id"],
            "name": r["item__name"] or "Unknown",
            "qty": r["qty"] or 0,
            "revenue": float(r["revenue"] or 0),
        }
        for r in top_items_qs
    ]

    return Response(
        {
            "period": period,
            "totalRevenue": total_revenue,
            "totalRetail": total_retail,
            "totalWholesale": total_wholesale,
            "totalSales": sales.count(),
            "topItems": top_items,
        }
    )


@api_view(["GET"])
def inventory_report(request):
    items = Item.objects.all()
    low_stock = items.filter(stock__lte=db_models.F("low_stock_threshold"))
    stock_value = float(
        items.aggregate(
            v=db_models.Sum(
                db_models.F("stock") * db_models.F("price"),
                output_field=db_models.FloatField(),
            )
        )["v"]
        or 0
    )

    low_stock_items = [
        {
            "id": i.id,
            "name": i.name,
            "stock": i.stock,
            "lowStockThreshold": i.low_stock_threshold,
        }
        for i in low_stock.order_by("stock")[:20]
    ]

    return Response(
        {
            "totalItems": items.count(),
            "lowStockCount": low_stock.count(),
            "stockValue": stock_value,
            "lowStockItems": low_stock_items,
        }
    )


@api_view(["GET"])
def customer_report(request):
    all_customers = Customer.objects.all()
    retail = all_customers.filter(is_wholesale=False).count()
    wholesale = all_customers.filter(is_wholesale=True).count()

    top_customers_qs = (
        Sale.objects.filter(customer__isnull=False)
        .values("customer__id", "customer__name")
        .annotate(spent=db_models.Sum("total_amount"))
        .order_by("-spent")[:10]
    )

    top_customers = [
        {
            "id": r["customer__id"],
            "name": r["customer__name"],
            "spent": float(r["spent"] or 0),
        }
        for r in top_customers_qs
    ]

    total_debt = float(
        all_customers.aggregate(d=db_models.Sum("outstanding_debt"))["d"] or 0
    )

    return Response(
        {
            "total": all_customers.count(),
            "retail": retail,
            "wholesale": wholesale,
            "totalDebt": total_debt,
            "topCustomers": top_customers,
        }
    )


@api_view(["GET"])
def profit_report(request):
    period = request.query_params.get("period", "month")
    start, end = _date_range(period)

    sales = Sale.objects.filter(created__date__gte=start, created__date__lte=end)
    revenue = float(sales.aggregate(t=db_models.Sum("total_amount"))["t"] or 0)

    # Calculate actual cost from sale items with cost_price data
    cost_from_items = SaleItem.objects.filter(
        sale__in=sales, item__isnull=False, item__cost__gt=0
    ).aggregate(
        total_cost=db_models.Sum(
            db_models.F("quantity") * F("item__cost"),
            output_field=db_models.FloatField(),
        )
    )["total_cost"]

    if cost_from_items and cost_from_items > 0:
        cost = float(cost_from_items)
        profit = revenue - cost
        margin = (profit / revenue * 100) if revenue > 0 else 0
    else:
        # Fallback: assume 30% margin if no cost data available
        cost = revenue * 0.70
        profit = revenue * 0.30
        margin = 30.0

    return Response(
        {
            "period": period,
            "revenue": revenue,
            "profit": profit,
            "margin": round(margin, 1),
        }
    )
