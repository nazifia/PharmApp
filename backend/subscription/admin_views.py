"""
SaaS Dashboard — superusers only.
Accessible at /admin/subscription/dashboard/

Shows:
  • Plan distribution summary (trial / starter / pro / enterprise)
  • MRR estimate
  • Trials expiring in next 7 days
  • Recently registered orgs
  • Orgs needing attention (expired / suspended)
"""
from django.contrib import admin
from django.core.exceptions import PermissionDenied
from django.db.models import Count, Q
from django.shortcuts import render
from django.utils import timezone

from .models import PlanPricing, Subscription


def saas_dashboard_view(request):
    if not request.user.is_superuser:
        raise PermissionDenied

    now = timezone.now()

    # ── Sync trial statuses before reading ────────────────────────────────────
    # Only update records whose computed status would differ (avoids mass writes)
    for sub in Subscription.objects.filter(
        plan='trial',
        trial_ends_at__lt=now,
    ).exclude(status__in=['expired', 'cancelled', 'suspended']):
        sub.refresh_status()
        sub.save(update_fields=['status'])

    # ── Plan distribution ─────────────────────────────────────────────────────
    dist = (
        Subscription.objects
        .values('plan')
        .annotate(count=Count('id'))
        .order_by('plan')
    )
    dist_map = {row['plan']: row['count'] for row in dist}

    plan_counts = {
        'trial':        dist_map.get('trial',        0),
        'starter':      dist_map.get('starter',      0),
        'professional': dist_map.get('professional', 0),
        'enterprise':   dist_map.get('enterprise',   0),
    }
    total_orgs = sum(plan_counts.values())

    # ── MRR estimate (uses live DB prices) ───────────────────────────────────
    live_prices = PlanPricing.get_all_prices()
    mrr = sum(
        plan_counts.get(plan, 0) * price
        for plan, price in live_prices.items()
        if plan != 'trial'
    )

    # ── Status breakdown ─────────────────────────────────────────────────────
    active_count    = Subscription.objects.filter(status='active').count()
    trial_count     = Subscription.objects.filter(status__in=['trial', 'expiring']).count()
    expired_count   = Subscription.objects.filter(status='expired').count()
    suspended_count = Subscription.objects.filter(status='suspended').count()

    # ── Trials expiring in next 7 days ────────────────────────────────────────
    in_7_days = now + timezone.timedelta(days=7)
    expiring_soon = (
        Subscription.objects
        .filter(
            plan='trial',
            trial_ends_at__gte=now,
            trial_ends_at__lte=in_7_days,
        )
        .select_related('organization')
        .order_by('trial_ends_at')
    )

    expiring_rows = []
    for sub in expiring_soon:
        days_left = (sub.trial_ends_at - now).days
        expiring_rows.append({
            'sub':       sub,
            'org':       sub.organization,
            'days_left': max(days_left, 0),
        })

    # ── Orgs needing attention (expired / suspended) ──────────────────────────
    attention_subs = (
        Subscription.objects
        .filter(status__in=['expired', 'suspended', 'cancelled'])
        .select_related('organization')
        .order_by('-updated_at')[:20]
    )

    # ── Recent new orgs (last 10) ─────────────────────────────────────────────
    recent_subs = (
        Subscription.objects
        .select_related('organization')
        .order_by('-created_at')[:10]
    )

    # ── Recently upgraded (plan != trial, active) ─────────────────────────────
    upgraded_subs = (
        Subscription.objects
        .filter(status='active')
        .exclude(plan='trial')
        .select_related('organization')
        .order_by('-updated_at')[:10]
    )

    context = {
        **admin.site.each_context(request),
        'title':           'SaaS Dashboard',

        # Summary
        'total_orgs':      total_orgs,
        'plan_counts':     plan_counts,
        'mrr':             mrr,
        'active_count':    active_count,
        'trial_count':     trial_count,
        'expired_count':   expired_count,
        'suspended_count': suspended_count,

        # Tables
        'expiring_rows':   expiring_rows,
        'attention_subs':  attention_subs,
        'recent_subs':     recent_subs,
        'upgraded_subs':   upgraded_subs,

        'now': now,
    }
    return render(request, 'admin/subscription/saas_dashboard.html', context)
