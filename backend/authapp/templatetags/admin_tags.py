"""
admin_tags — context helpers for the PharmApp admin dashboard.
Loaded in templates with {% load admin_tags %}.
"""
from django import template
from django.db.models import Sum, Count, Max
from django.utils.timezone import now

register = template.Library()


@register.simple_tag(takes_context=True)
def org_dashboard_stats(context):
    """
    Returns a dict of quick-stats for the current admin user.
    Superusers get platform-wide totals; org-staff get org-scoped totals.
    """
    request = context.get("request")
    if not request:
        return {}

    user = request.user

    try:
        from inventory.models import Item
        from customers.models import Customer
        from pos.models import Sale, Expense, PaymentRequest
        from authapp.models import Organization, PharmUser

        if user.is_superuser:
            return _platform_stats(Organization, PharmUser, Item, Customer, Sale, Expense)
        else:
            org = getattr(user, "organization", None)
            if org is None:
                return {}
            return _org_stats(org, PharmUser, Item, Customer, Sale, Expense, PaymentRequest)
    except Exception:
        return {}


# ── Platform-wide stats (superuser) ──────────────────────────────────────────

def _platform_stats(Organization, PharmUser, Item, Customer, Sale, Expense):
    today = now().date()

    total_orgs      = Organization.objects.count()
    total_users     = PharmUser.objects.filter(is_superuser=False, is_active=True).count()
    total_items     = Item.objects.count()
    total_customers = Customer.objects.count()

    completed_sales = Sale.objects.filter(status="completed")
    today_sales     = completed_sales.filter(created__date=today)

    total_revenue   = completed_sales.aggregate(v=Sum("total_amount"))["v"] or 0
    today_revenue   = today_sales.aggregate(v=Sum("total_amount"))["v"] or 0
    total_expenses  = Expense.objects.aggregate(v=Sum("amount"))["v"] or 0

    out_of_stock    = Item.objects.filter(stock__lte=0).count()
    low_stock       = Item.objects.filter(stock__gt=0).extra(
        where=["stock <= low_stock_threshold"]
    ).count()

    recent_orgs = Organization.objects.order_by("-created_at")[:5]

    return {
        "is_superuser":   True,
        "total_orgs":     total_orgs,
        "total_users":    total_users,
        "total_items":    total_items,
        "total_customers": total_customers,
        "total_sales":    completed_sales.count(),
        "today_sales":    today_sales.count(),
        "total_revenue":  float(total_revenue),
        "today_revenue":  float(today_revenue),
        "total_expenses": float(total_expenses),
        "net_revenue":    float(total_revenue) - float(total_expenses),
        "out_of_stock":   out_of_stock,
        "low_stock":      low_stock,
        "recent_orgs":    recent_orgs,
    }


# ── Org-scoped stats (org admin) ──────────────────────────────────────────────

def _org_stats(org, PharmUser, Item, Customer, Sale, Expense, PaymentRequest):
    today = now().date()

    users_qs     = PharmUser.objects.filter(organization=org, is_superuser=False)
    items_qs     = Item.objects.filter(organization=org)
    customers_qs = Customer.objects.filter(organization=org)
    sales_qs     = Sale.objects.filter(organization=org, status="completed")
    today_sales  = sales_qs.filter(created__date=today)
    expenses_qs  = Expense.objects.filter(organization=org)
    pending_reqs = PaymentRequest.objects.filter(organization=org, status="pending")

    total_revenue  = sales_qs.aggregate(v=Sum("total_amount"))["v"] or 0
    today_revenue  = today_sales.aggregate(v=Sum("total_amount"))["v"] or 0
    total_expenses = expenses_qs.aggregate(v=Sum("amount"))["v"] or 0
    last_sale      = Sale.objects.filter(organization=org).aggregate(v=Max("created"))["v"]

    out_of_stock = items_qs.filter(stock__lte=0).count()
    low_stock    = items_qs.filter(stock__gt=0).extra(
        where=["stock <= low_stock_threshold"]
    ).count()

    return {
        "is_superuser":    False,
        "org":             org,
        "active_users":    users_qs.filter(is_active=True).count(),
        "total_users":     users_qs.count(),
        "total_items":     items_qs.filter(status="active").count(),
        "out_of_stock":    out_of_stock,
        "low_stock":       low_stock,
        "total_customers": customers_qs.count(),
        "total_sales":     sales_qs.count(),
        "today_sales":     today_sales.count(),
        "total_revenue":   float(total_revenue),
        "today_revenue":   float(today_revenue),
        "total_expenses":  float(total_expenses),
        "net_revenue":     float(total_revenue) - float(total_expenses),
        "pending_requests": pending_reqs.count(),
        "last_sale":       last_sale,
    }
