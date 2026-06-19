"""
Global overview admin view — superusers only.

Accessible at /admin/overview/ and linked from the Jazzmin top menu.
Shows a cross-organisation summary dashboard for the software owner/developer.
"""
from django.contrib import admin
from django.core.exceptions import PermissionDenied
from django.db.models import Count, Sum, Max, F, Q, FloatField
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

    # One grouped query per related model (was ~6 queries *per org*). Each maps
    # org_id → its aggregates; we stitch them together in the loop below.
    def _by_org(qs, group_field, **aggs):
        return {
            row[group_field]: row
            for row in qs.values(group_field).annotate(**aggs)
        }

    users_map = _by_org(
        PharmUser.objects.filter(is_superuser=False), "organization",
        total=Count("id"),
        active=Count("id", filter=Q(is_active=True)),
    )
    items_map = _by_org(
        Item.objects.all(), "organization",
        total=Count("id"),
        low_stock=Count("id", filter=Q(stock__gt=0, stock__lte=F("low_stock_threshold"))),
        out_of_stock=Count("id", filter=Q(stock__lte=0)),
        stock_value=Sum(F("stock") * F("price"), output_field=FloatField()),
    )
    customers_map = _by_org(
        Customer.objects.all(), "organization", total=Count("id"),
    )
    completed_map = _by_org(
        Sale.objects.filter(status="completed"), "organization",
        total=Count("id"),
        revenue=Sum("total_amount"),
    )
    sales_map = _by_org(
        Sale.objects.all(), "organization",
        total=Count("id"),
        last_sale=Max("created"),
    )
    expenses_map = _by_org(
        Expense.objects.all(), "organization", total=Sum("amount"),
    )

    org_rows = []
    for org in orgs:
        u  = users_map.get(org.id, {})
        it = items_map.get(org.id, {})
        c  = customers_map.get(org.id, {})
        cs = completed_map.get(org.id, {})
        s  = sales_map.get(org.id, {})

        revenue       = cs.get("revenue") or 0
        expenses      = expenses_map.get(org.id, {}).get("total") or 0
        completed_cnt = cs.get("total") or 0
        total_cnt     = s.get("total") or 0

        org_rows.append({
            "org":            org,
            "active_users":   u.get("active") or 0,
            "total_users":    u.get("total") or 0,
            "total_items":    it.get("total") or 0,
            "low_stock":      it.get("low_stock") or 0,
            "out_of_stock":   it.get("out_of_stock") or 0,
            "stock_value":    it.get("stock_value") or 0,
            "total_customers": c.get("total") or 0,
            "completed_sales": completed_cnt,
            "total_sales":    total_cnt,
            "other_sales":    total_cnt - completed_cnt,
            "revenue":        revenue,
            "expenses":       expenses,
            "net":            revenue - expenses,
            "last_sale":      s.get("last_sale"),
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
