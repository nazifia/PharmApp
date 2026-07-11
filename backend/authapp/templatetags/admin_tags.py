"""
admin_tags — context helpers for the PharmApp admin dashboard.
Loaded in templates with {% load admin_tags %}.
"""
from datetime import timedelta

from django import template
from django.db.models import Sum, Count, Max, Q, F
from django.utils.timezone import localdate

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
    today = localdate()

    total_orgs      = Organization.objects.count()
    total_users     = PharmUser.objects.filter(is_superuser=False, is_active=True).count()
    total_customers = Customer.objects.count()

    sale_agg = Sale.objects.filter(status="completed").aggregate(
        total_sales=Count("id"),
        total_revenue=Sum("total_amount"),
        today_sales=Count("id", filter=Q(created__date=today)),
        today_revenue=Sum("total_amount", filter=Q(created__date=today)),
    )

    item_agg = Item.objects.aggregate(
        total=Count("id"),
        out=Count("id", filter=Q(stock__lte=0)),
        low=Count("id", filter=Q(stock__gt=0, stock__lte=F("low_stock_threshold"))),
    )

    total_expenses = Expense.objects.aggregate(v=Sum("amount"))["v"] or 0
    total_revenue  = sale_agg["total_revenue"] or 0

    recent_orgs = Organization.objects.order_by("-created_at")[:5]

    # ── Subscription stats ────────────────────────────────────────────────────
    sub_stats = _subscription_platform_stats()

    return {
        "is_superuser":   True,
        "total_orgs":     total_orgs,
        "total_users":    total_users,
        "total_items":    item_agg["total"],
        "total_customers": total_customers,
        "total_sales":    sale_agg["total_sales"],
        "today_sales":    sale_agg["today_sales"],
        "total_revenue":  float(total_revenue),
        "today_revenue":  float(sale_agg["today_revenue"] or 0),
        "total_expenses": float(total_expenses),
        "net_revenue":    float(total_revenue) - float(total_expenses),
        "out_of_stock":   item_agg["out"],
        "low_stock":      item_agg["low"],
        "recent_orgs":    recent_orgs,
        **sub_stats,
    }


# ── Org-scoped stats (org admin) ──────────────────────────────────────────────

def _org_stats(org, PharmUser, Item, Customer, Sale, Expense, PaymentRequest):
    today = localdate()

    user_agg = PharmUser.objects.filter(organization=org, is_superuser=False).aggregate(
        total=Count("id"),
        active=Count("id", filter=Q(is_active=True)),
    )

    item_agg = Item.objects.filter(organization=org).aggregate(
        active=Count("id", filter=Q(status="active")),
        out=Count("id", filter=Q(stock__lte=0)),
        low=Count("id", filter=Q(stock__gt=0, stock__lte=F("low_stock_threshold"))),
    )

    sale_agg = Sale.objects.filter(organization=org).aggregate(
        total_sales=Count("id", filter=Q(status="completed")),
        total_revenue=Sum("total_amount", filter=Q(status="completed")),
        today_sales=Count("id", filter=Q(status="completed", created__date=today)),
        today_revenue=Sum("total_amount", filter=Q(status="completed", created__date=today)),
        last_sale=Max("created"),
    )

    total_customers = Customer.objects.filter(organization=org).count()
    total_expenses  = Expense.objects.filter(organization=org).aggregate(v=Sum("amount"))["v"] or 0
    pending_count   = PaymentRequest.objects.filter(organization=org, status="pending").count()

    total_revenue = sale_agg["total_revenue"] or 0

    # ── Subscription stats ────────────────────────────────────────────────────
    sub_stats = _subscription_org_stats(org)

    return {
        "is_superuser":    False,
        "org":             org,
        "active_users":    user_agg["active"],
        "total_users":     user_agg["total"],
        "total_items":     item_agg["active"],
        "out_of_stock":    item_agg["out"],
        "low_stock":       item_agg["low"],
        "total_customers": total_customers,
        "total_sales":     sale_agg["total_sales"],
        "today_sales":     sale_agg["today_sales"],
        "total_revenue":   float(total_revenue),
        "today_revenue":   float(sale_agg["today_revenue"] or 0),
        "total_expenses":  float(total_expenses),
        "net_revenue":     float(total_revenue) - float(total_expenses),
        "pending_requests": pending_count,
        "last_sale":       sale_agg["last_sale"],
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

        agg = Subscription.objects.aggregate(
            trial=Count("id", filter=Q(plan="trial")),
            starter=Count("id", filter=Q(plan="starter")),
            professional=Count("id", filter=Q(plan="professional")),
            enterprise=Count("id", filter=Q(plan="enterprise")),
            active=Count("id", filter=Q(status="active")),
            expired=Count("id", filter=Q(status="expired")),
            suspended=Count("id", filter=Q(status="suspended")),
            expiring=Count("id", filter=Q(
                plan="trial",
                trial_ends_at__gte=_now_dt,
                trial_ends_at__lte=in_7,
            )),
        )

        plan_counts = {
            'trial':        agg["trial"],
            'starter':      agg["starter"],
            'professional': agg["professional"],
            'enterprise':   agg["enterprise"],
        }

        live_prices = PlanPricing.get_all_prices()
        mrr = sum(
            plan_counts.get(plan, 0) * price
            for plan, price in live_prices.items()
            if plan != 'trial'
        )

        return {
            "sub_plan_counts": plan_counts,
            "sub_mrr":         round(mrr, 2),
            "sub_active":      agg["active"],
            "sub_expiring":    agg["expiring"],
            "sub_expired":     agg["expired"],
            "sub_suspended":   agg["suspended"],
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
