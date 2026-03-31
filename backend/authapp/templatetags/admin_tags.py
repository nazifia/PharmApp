"""
admin_tags — context helpers for the PharmApp admin dashboard.
Loaded in templates with {% load admin_tags %}.
"""
from datetime import timedelta

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

    # ── Subscription stats ────────────────────────────────────────────────────
    sub_stats = _subscription_platform_stats()

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
        **sub_stats,
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

    # ── Subscription stats ────────────────────────────────────────────────────
    sub_stats = _subscription_org_stats(org)

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
        **sub_stats,
    }


# ── Subscription helpers ──────────────────────────────────────────────────────

def _subscription_platform_stats():
    """Platform-wide subscription KPIs for the superuser dashboard."""
    try:
        from subscription.models import Subscription, PlanPricing
        from django.utils.timezone import now as _now

        _now_dt = _now()
        in_7 = _now_dt + timedelta(days=7)

        plan_counts = {
            'trial':        Subscription.objects.filter(plan='trial').count(),
            'starter':      Subscription.objects.filter(plan='starter').count(),
            'professional': Subscription.objects.filter(plan='professional').count(),
            'enterprise':   Subscription.objects.filter(plan='enterprise').count(),
        }

        live_prices = PlanPricing.get_all_prices()
        mrr = sum(
            plan_counts.get(plan, 0) * price
            for plan, price in live_prices.items()
            if plan != 'trial'
        )

        return {
            "sub_plan_counts":    plan_counts,
            "sub_mrr":            round(mrr, 2),
            "sub_active":         Subscription.objects.filter(status='active').count(),
            "sub_expiring":       Subscription.objects.filter(
                                      plan='trial',
                                      trial_ends_at__gte=_now_dt,
                                      trial_ends_at__lte=in_7,
                                  ).count(),
            "sub_expired":        Subscription.objects.filter(status='expired').count(),
            "sub_suspended":      Subscription.objects.filter(status='suspended').count(),
        }
    except Exception:
        return {}


def _subscription_org_stats(org):
    """Per-org subscription info for the org-admin dashboard."""
    try:
        from subscription.models import Subscription
        from django.utils.timezone import now as _now

        sub = Subscription.objects.get(organization=org)
        sub.refresh_status()
        days = None
        if sub.plan == 'trial' and sub.trial_ends_at:
            days = max((sub.trial_ends_at - _now()).days, 0)
        return {
            "subscription":         sub,
            "sub_plan":             sub.plan,
            "sub_plan_display":     sub.get_plan_display(),
            "sub_status":           sub.status,
            "sub_status_display":   sub.get_status_display(),
            "sub_trial_days":       days,
            "sub_is_trial":         sub.plan == 'trial',
            "sub_is_expiring":      sub.status in ('expiring', 'expired'),
        }
    except Exception:
        return {}
