"""
Global overview admin view — superusers only.

Accessible at /admin/overview/ and linked from the Jazzmin top menu.
Shows a cross-organisation summary dashboard for the software owner/developer.
"""
from django.contrib import admin
from django.core.exceptions import PermissionDenied
from django.db.models import Count, Sum, Max
from django.shortcuts import render
from django.utils.timezone import now

from .models import Organization, PharmUser


def global_overview_view(request):
    """
    Renders a cross-org summary dashboard.
    Wrapped with admin.site.admin_view() in urls.py, so authentication
    is handled automatically. We additionally restrict to superusers.
    """
    if not request.user.is_superuser:
        raise PermissionDenied

    # ── Top-level platform stats ──────────────────────────────────────────────

    from inventory.models import Item
    from customers.models import Customer
    from pos.models import Sale, Expense

    total_orgs     = Organization.objects.count()
    total_users    = PharmUser.objects.filter(is_superuser=False).count()
    total_items    = Item.objects.count()
    total_customers = Customer.objects.count()
    total_sales    = Sale.objects.filter(status="completed").count()
    total_revenue  = Sale.objects.filter(status="completed").aggregate(
        v=Sum("total_amount")
    )["v"] or 0
    total_expenses = Expense.objects.aggregate(v=Sum("amount"))["v"] or 0

    # ── Per-organisation breakdown ────────────────────────────────────────────

    orgs = Organization.objects.order_by("name")

    org_rows = []
    for org in orgs:
        users       = PharmUser.objects.filter(organization=org, is_superuser=False)
        items       = Item.objects.filter(organization=org)
        customers   = Customer.objects.filter(organization=org)
        sales_qs    = Sale.objects.filter(organization=org, status="completed")
        all_sales   = Sale.objects.filter(organization=org)
        expenses_qs = Expense.objects.filter(organization=org)

        revenue  = sales_qs.aggregate(v=Sum("total_amount"))["v"] or 0
        expenses = expenses_qs.aggregate(v=Sum("amount"))["v"] or 0
        last_sale = all_sales.aggregate(v=Max("created"))["v"]
        stock_val = items.aggregate(
            v=Sum("price")
        )["v"] or 0

        org_rows.append({
            "org":            org,
            "active_users":   users.filter(is_active=True).count(),
            "total_users":    users.count(),
            "total_items":    items.count(),
            "low_stock":      items.filter(stock__gt=0).extra(
                                  where=["stock <= low_stock_threshold"]
                              ).count(),
            "out_of_stock":   items.filter(stock__lte=0).count(),
            "stock_value":    stock_val,
            "total_customers": customers.count(),
            "completed_sales": sales_qs.count(),
            "total_sales":    all_sales.count(),
            "revenue":        revenue,
            "expenses":       expenses,
            "net":            revenue - expenses,
            "last_sale":      last_sale,
        })

    # Sort by revenue descending
    org_rows.sort(key=lambda r: r["revenue"], reverse=True)

    # ── Recent registrations ──────────────────────────────────────────────────

    recent_orgs = Organization.objects.order_by("-created_at")[:5]

    context = {
        **admin.site.each_context(request),
        # Platform totals
        "total_orgs":      total_orgs,
        "total_users":     total_users,
        "total_items":     total_items,
        "total_customers": total_customers,
        "total_sales":     total_sales,
        "total_revenue":   total_revenue,
        "total_expenses":  total_expenses,
        "net_revenue":     float(total_revenue) - float(total_expenses),
        # Per-org table
        "org_rows":        org_rows,
        # Recent
        "recent_orgs":     recent_orgs,
        "now":             now(),
        # Admin page metadata
        "title":           "Global Overview",
    }
    return render(request, "admin/global_overview.html", context)
