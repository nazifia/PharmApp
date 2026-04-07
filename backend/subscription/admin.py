"""
Full-featured SaaS admin for the Subscription model.
Superusers only — org staff have no access.

Change-page features
────────────────────
  • Quick-action buttons  : extend trial, activate plan, suspend, reactivate,
                            cancel, reset — all one click, no raw field editing
  • Smart save_model      : auto-adjusts status when plan changes (trial→paid
                            forces 'active'; paid→trial recalculates from dates)
  • Plan features panel   : shows feature list and hard limits for current plan
  • Live usage panel      : users / items / transactions with progress bars
  • Audit event log       : every change recorded in SubscriptionEvent inline

List-page features
──────────────────
  • Bulk actions          : all quick actions available as bulk operations
  • Usage columns         : live users / items / transactions / trial days left
  • Plan & status badges  : colour-coded chips
"""
from datetime import timedelta
from decimal import Decimal, InvalidOperation

from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied
from django.http import HttpResponseRedirect
from django.urls import reverse
from django.utils import timezone
from django.utils.html import conditional_escape, format_html
from django.utils.safestring import mark_safe

from .models import (
    FEATURE_KEY_CHOICES, PLAN_CHOICES, PLAN_FEATURES, PLAN_FEATURES_DEFAULT,
    PLAN_LIMITS, PLAN_PRICES, SUPPORTED_CURRENCIES,
    PlanFeatureFlag, PlanPricing, Subscription, SubscriptionEvent,
)

# ── Colour helpers ─────────────────────────────────────────────────────────────

PLAN_COLORS = {
    'trial':        '#F59E0B',
    'starter':      '#3B82F6',
    'professional': '#8B5CF6',
    'enterprise':   '#06B6D4',
}
STATUS_COLORS = {
    'active':    '#10B981',
    'trial':     '#3B82F6',
    'expiring':  '#F59E0B',
    'expired':   '#EF4444',
    'suspended': '#DC2626',
    'cancelled': '#6B7280',
}


def _badge(text, color):
    return format_html(
        '<span style="background:{c};color:#fff;padding:2px 10px;'
        'border-radius:12px;font-size:11px;font-weight:600">{t}</span>',
        c=color, t=text,
    )


# ── Audit-log inline ───────────────────────────────────────────────────────────

class SubscriptionEventInline(admin.TabularInline):
    model         = SubscriptionEvent
    extra         = 0
    can_delete    = False
    max_num       = 0          # no "add" row
    verbose_name  = 'Event'
    verbose_name_plural = 'Audit Log'
    ordering      = ('-created_at',)

    readonly_fields = ('created_at', 'event_type', 'old_value', 'new_value',
                       'performed_by', 'note')
    fields          = ('created_at', 'event_type', 'old_value', 'new_value',
                       'performed_by', 'note')

    def has_add_permission(self, request, obj=None):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser


# ── Inline for OrganizationAdmin ──────────────────────────────────────────────

class SubscriptionInline(admin.StackedInline):
    model        = Subscription
    extra        = 0
    max_num      = 1
    can_delete   = False
    verbose_name = 'Subscription'
    verbose_name_plural = 'Subscription'

    fields = (
        ('plan', 'status'),
        ('trial_ends_at', 'current_period_end'),
        'external_subscription_id',
    )

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser


# ── Bulk actions ───────────────────────────────────────────────────────────────

@admin.action(description='⏳  Extend trial by 7 days')
def extend_trial_7(modeladmin, request, queryset):
    n = 0
    for sub in queryset:
        base = max(sub.trial_ends_at or timezone.now(), timezone.now())
        sub.trial_ends_at = base + timedelta(days=7)
        sub.plan = 'trial'
        sub.save()
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='trial_extended',
            old_value=str(sub.trial_ends_at - timedelta(days=7))[:16],
            new_value=str(sub.trial_ends_at)[:16],
            performed_by=request.user.phone_number, note='Bulk: +7 days',
        )
        n += 1
    modeladmin.message_user(request, f'Trial extended +7 days for {n} subscription(s).', messages.SUCCESS)


@admin.action(description='⏳  Extend trial by 30 days')
def extend_trial_30(modeladmin, request, queryset):
    n = 0
    for sub in queryset:
        base = max(sub.trial_ends_at or timezone.now(), timezone.now())
        sub.trial_ends_at = base + timedelta(days=30)
        sub.plan = 'trial'
        sub.save()
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='trial_extended',
            new_value=str(sub.trial_ends_at)[:16],
            performed_by=request.user.phone_number, note='Bulk: +30 days',
        )
        n += 1
    modeladmin.message_user(request, f'Trial extended +30 days for {n} subscription(s).', messages.SUCCESS)


@admin.action(description='🚀  Activate — Starter plan')
def activate_starter(modeladmin, request, queryset):
    for sub in queryset:
        old = sub.plan
        sub.plan = 'starter'; sub.status = 'active'; sub.trial_ends_at = None
        sub.save()
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='activated',
            old_value=old, new_value='starter',
            performed_by=request.user.phone_number,
        )
    modeladmin.message_user(request, f'{queryset.count()} subscription(s) → Starter (active).', messages.SUCCESS)


@admin.action(description='💎  Activate — Professional plan')
def activate_professional(modeladmin, request, queryset):
    for sub in queryset:
        old = sub.plan
        sub.plan = 'professional'; sub.status = 'active'; sub.trial_ends_at = None
        sub.save()
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='activated',
            old_value=old, new_value='professional',
            performed_by=request.user.phone_number,
        )
    modeladmin.message_user(request, f'{queryset.count()} subscription(s) → Professional (active).', messages.SUCCESS)


@admin.action(description='👑  Activate — Enterprise plan')
def activate_enterprise(modeladmin, request, queryset):
    for sub in queryset:
        old = sub.plan
        sub.plan = 'enterprise'; sub.status = 'active'; sub.trial_ends_at = None
        sub.save()
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='activated',
            old_value=old, new_value='enterprise',
            performed_by=request.user.phone_number,
        )
    modeladmin.message_user(request, f'{queryset.count()} subscription(s) → Enterprise (active).', messages.SUCCESS)


@admin.action(description='🔄  Reset to 14-day trial')
def reset_to_trial(modeladmin, request, queryset):
    for sub in queryset:
        old = f"{sub.plan}/{sub.status}"
        sub.plan = 'trial'; sub.status = 'trial'; sub.billing_cycle = 'monthly'
        sub.trial_ends_at = timezone.now() + timedelta(days=14)
        sub.current_period_end = None; sub.external_subscription_id = ''
        sub.save()
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='reset',
            old_value=old, new_value='trial/trial',
            performed_by=request.user.phone_number,
        )
    modeladmin.message_user(request, f'{queryset.count()} subscription(s) reset to 14-day trial.', messages.SUCCESS)


@admin.action(description='⚠️  Suspend subscriptions')
def suspend_subscriptions(modeladmin, request, queryset):
    for sub in queryset:
        old = sub.status
        sub.status = 'suspended'
        sub.save(update_fields=['status', 'updated_at'])
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='suspended',
            old_value=old, new_value='suspended',
            performed_by=request.user.phone_number,
        )
    modeladmin.message_user(request, f'{queryset.count()} subscription(s) suspended.', messages.WARNING)


@admin.action(description='✅  Reactivate suspended subscriptions')
def reactivate_subscriptions(modeladmin, request, queryset):
    n = 0
    for sub in queryset.filter(status='suspended'):
        sub.status = 'active' if sub.plan != 'trial' else 'trial'
        sub.save(update_fields=['status', 'updated_at'])
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='reactivated',
            old_value='suspended', new_value=sub.status,
            performed_by=request.user.phone_number,
        )
        n += 1
    modeladmin.message_user(request, f'{n} subscription(s) reactivated.', messages.SUCCESS)


# ── Main SubscriptionAdmin ────────────────────────────────────────────────────

@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):

    change_form_template = 'admin/subscription/subscription/change_form.html'

    list_display = (
        'organization_link', 'plan_badge', 'status_badge',
        'trial_days_left', 'usage_users', 'usage_items',
        'usage_transactions', 'current_period_end', 'updated_at',
    )
    list_filter   = ('plan', 'status')
    search_fields = ('organization__name', 'organization__slug',
                     'external_subscription_id')
    ordering      = ('-created_at',)
    date_hierarchy = 'created_at'

    readonly_fields = (
        'created_at', 'updated_at',
        'live_usage_panel', 'plan_features_panel',
        'subscription_summary', 'feature_override_panel',
    )

    fieldsets = (
        # Tab: organisation-tab
        ('Organisation', {
            'fields': ('subscription_summary', 'organization'),
        }),
        # Tab: plan-billing-tab
        ('Plan & Billing', {
            'fields': (
                ('plan', 'status'),
                ('billing_cycle', 'current_period_end'),
                'trial_ends_at',
                'external_subscription_id',
            ),
            'description': (
                'Changing <strong>Plan</strong> to a paid tier auto-sets status '
                'to <em>Active</em> and clears the trial date. '
                'Changing to <em>Trial</em> recalculates status from the trial end date. '
                '<strong>Billing Cycle</strong>: Monthly = charged each month; '
                'Annual = charged once per year at the discounted annual price.'
            ),
        }),
        # Tab: feature-overrides-tab
        ('Feature Overrides', {
            'fields': (
                'feature_override_panel',
                'extra_features',
                'removed_features',
            ),
            'description': (
                'Override which features this org has access to, independent of their plan. '
                '<br><strong>Extra features</strong>: JSON list of feature keys to enable beyond '
                'the plan (e.g. <code>["wholesale", "advanced_reports"]</code>). '
                '<br><strong>Removed features</strong>: JSON list of feature keys to disable '
                '(e.g. <code>["export_data"]</code>). '
                '<br>Valid keys: pos, inventory, customers, user_management, basic_reports, '
                'advanced_reports, wholesale, export_data, multi_branch, api_access, '
                'priority_support, white_label'
            ),
        }),
        # Tab: custom-limits-tab
        ('Usage Limit Overrides', {
            'fields': (
                'custom_max_users',
                'custom_max_items',
                'custom_max_transactions',
                'custom_max_branches',
            ),
            'description': (
                'Override usage limits for this org. Leave blank to use the plan default. '
                'Enter <strong>-1</strong> for unlimited.'
            ),
        }),
        # Tab: plan-features-tab
        ('Plan Features (read-only)', {
            'fields': ('plan_features_panel',),
        }),
        # Tab: live-usage-tab
        ('Live Usage', {
            'fields': ('live_usage_panel',),
        }),
        # Tab: timestamps-tab
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
        }),
        # audit-log-tab is generated automatically from SubscriptionEventInline
    )

    inlines = [SubscriptionEventInline]

    actions = [
        extend_trial_7, extend_trial_30,
        activate_starter, activate_professional, activate_enterprise,
        reset_to_trial,
        suspend_subscriptions, reactivate_subscriptions,
    ]

    # ── Permissions ─────────────────────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser

    # ── Change view — intercepts quick-action POST ───────────────────────────

    def change_view(self, request, object_id, form_url='', extra_context=None):
        obj = self.get_object(request, object_id)
        if obj is None:
            return self._get_obj_does_not_exist_redirect(
                request, self.model._meta, object_id
            )

        # Handle quick-action buttons before the normal form processing
        if request.method == 'POST' and '_quick_action' in request.POST:
            action = request.POST['_quick_action']
            note   = request.POST.get('action_note', '').strip()
            redirect = self._handle_quick_action(request, obj, action, note)
            if redirect:
                return redirect

        extra_context = extra_context or {}
        extra_context.update(self._change_context(obj))
        return super().change_view(request, object_id, form_url, extra_context)

    def _change_context(self, obj):
        """Extra template context for the change form."""
        obj.refresh_status()
        now  = timezone.now()
        days = None
        if obj.plan == 'trial' and obj.trial_ends_at:
            days = (obj.trial_ends_at - now).days

        # Fetch live prices for all paid plans to show on activate buttons
        pricing = {}
        for pp in PlanPricing.objects.all():
            pricing[pp.plan] = pp

        return {
            'plan_color':        PLAN_COLORS.get(obj.plan, '#6B7280'),
            'status_color':      STATUS_COLORS.get(obj.status, '#6B7280'),
            'trial_days':        days,
            'plan_price':        float(PlanPricing.get_price(obj.plan)),
            'plan_label':        dict(obj._meta.get_field('plan').choices).get(obj.plan, obj.plan),
            'status_label':      dict(obj._meta.get_field('status').choices).get(obj.status, obj.status),
            'is_trial':          obj.plan == 'trial',
            'is_paid':           obj.plan != 'trial',
            'is_suspended':      obj.status == 'suspended',
            'is_cancelled':      obj.status == 'cancelled',
            'is_active':         obj.status == 'active',
            'is_expired':        obj.status == 'expired',
            'is_annual':         obj.billing_cycle == 'annual',
            'billing_cycle':     obj.billing_cycle,
            'plan_pricing':      pricing,   # {plan: PlanPricing obj}
        }

    def _handle_quick_action(self, request, obj, action, note=''):
        """Execute a quick action and redirect back to the change page."""
        actor = request.user.phone_number
        url   = reverse(
            f'admin:{obj._meta.app_label}_{obj._meta.model_name}_change',
            args=[obj.pk],
        )

        def _redirect(msg, level=messages.SUCCESS):
            self.message_user(request, msg, level)
            return HttpResponseRedirect(url)

        # ── Extend trial ──────────────────────────────────────────────────
        if action in ('extend_7', 'extend_30'):
            days = 7 if action == 'extend_7' else 30
            base = max(obj.trial_ends_at or timezone.now(), timezone.now())
            old_end = str(obj.trial_ends_at)[:16] if obj.trial_ends_at else '—'
            obj.trial_ends_at = base + timedelta(days=days)
            obj.plan = 'trial'
            # clear suspended/cancelled so refresh_status works
            if obj.status in ('suspended', 'cancelled', 'expired'):
                obj.status = 'trial'
            obj.save()
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='trial_extended',
                old_value=old_end,
                new_value=str(obj.trial_ends_at)[:16],
                performed_by=actor,
                note=note or f'+{days} days',
            )
            return _redirect(
                f"Trial extended by {days} days. New end: "
                f"{obj.trial_ends_at.strftime('%Y-%m-%d %H:%M')} UTC."
            )

        # ── Activate a specific paid plan (monthly or annual) ─────────────
        _activate_map = {
            'activate_starter':         ('starter',      'monthly'),
            'activate_professional':    ('professional', 'monthly'),
            'activate_enterprise':      ('enterprise',   'monthly'),
            'activate_starter_annual':      ('starter',      'annual'),
            'activate_professional_annual': ('professional', 'annual'),
            'activate_enterprise_annual':   ('enterprise',   'annual'),
        }
        if action in _activate_map:
            new_plan, cycle = _activate_map[action]
            old_plan = obj.plan
            obj.plan          = new_plan
            obj.billing_cycle = cycle
            obj.status        = 'active'
            obj.trial_ends_at = None
            obj.save()
            cycle_label = 'annually' if cycle == 'annual' else 'monthly'
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='activated',
                old_value=old_plan, new_value=new_plan,
                performed_by=actor,
                note=note or f'Billed {cycle_label}',
            )
            return _redirect(
                f"Subscription activated on {new_plan.title()} plan ({cycle_label})."
            )

        # ── Suspend ───────────────────────────────────────────────────────
        if action == 'suspend':
            if obj.status == 'suspended':
                return _redirect("Already suspended — no change.", messages.WARNING)
            old_status    = obj.status
            obj.status    = 'suspended'
            obj.save(update_fields=['status', 'updated_at'])
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='suspended',
                old_value=old_status, new_value='suspended',
                performed_by=actor, note=note,
            )
            return _redirect(
                f"Subscription for {obj.organization.name} suspended.",
                messages.WARNING,
            )

        # ── Reactivate ────────────────────────────────────────────────────
        if action == 'reactivate':
            if obj.status not in ('suspended', 'cancelled', 'expired'):
                return _redirect("Subscription is already active — no change.", messages.WARNING)
            old_status = obj.status
            obj.status = 'active' if obj.plan != 'trial' else 'trial'
            obj.save(update_fields=['status', 'updated_at'])
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='reactivated',
                old_value=old_status, new_value=obj.status,
                performed_by=actor, note=note,
            )
            return _redirect(
                f"Subscription for {obj.organization.name} reactivated."
            )

        # ── Cancel ────────────────────────────────────────────────────────
        if action == 'cancel':
            if obj.status == 'cancelled':
                return _redirect("Already cancelled — no change.", messages.WARNING)
            old_status = obj.status
            obj.status = 'cancelled'
            obj.save(update_fields=['status', 'updated_at'])
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='cancelled',
                old_value=old_status, new_value='cancelled',
                performed_by=actor, note=note,
            )
            return _redirect(
                f"Subscription for {obj.organization.name} cancelled.",
                messages.WARNING,
            )

        # ── Reset to fresh trial ──────────────────────────────────────────
        if action == 'reset':
            old = f"{obj.plan}/{obj.status}"
            obj.plan                    = 'trial'
            obj.status                  = 'trial'
            obj.billing_cycle           = 'monthly'
            obj.trial_ends_at           = timezone.now() + timedelta(days=14)
            obj.current_period_end      = None
            obj.external_subscription_id = ''
            obj.save()
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='reset',
                old_value=old, new_value='trial/trial',
                performed_by=actor, note=note,
            )
            return _redirect(
                f"Subscription reset to 14-day trial. "
                f"Ends {obj.trial_ends_at.strftime('%Y-%m-%d')}."
            )

        # Unknown action — fall through to normal form processing
        return None

    # ── Smart save_model ─────────────────────────────────────────────────────

    def save_model(self, request, obj, form, change):
        if change and 'plan' in form.changed_data:
            try:
                original = Subscription.objects.get(pk=obj.pk)
                old_plan = original.plan
            except Subscription.DoesNotExist:
                old_plan = ''

            # Paid plan selected → force active, clear trial fields
            if obj.plan != 'trial' and obj.status in ('trial', 'expiring', 'expired'):
                obj.status        = 'active'
                obj.trial_ends_at = None

            # Trial selected from paid → let refresh_status compute status
            if obj.plan == 'trial' and obj.status == 'active':
                obj.status = ''  # will be set by refresh_status in save()

            super().save_model(request, obj, form, change)

            SubscriptionEvent.objects.create(
                subscription=obj,
                event_type='plan_changed',
                old_value=old_plan,
                new_value=obj.plan,
                performed_by=request.user.phone_number,
                note='Changed via admin form',
            )

        elif change and 'status' in form.changed_data:
            try:
                original = Subscription.objects.get(pk=obj.pk)
                old_status = original.status
            except Subscription.DoesNotExist:
                old_status = ''

            super().save_model(request, obj, form, change)

            SubscriptionEvent.objects.create(
                subscription=obj,
                event_type='status_changed',
                old_value=old_status,
                new_value=obj.status,
                performed_by=request.user.phone_number,
                note='Changed via admin form',
            )
        elif change and any(
            f in form.changed_data
            for f in ('extra_features', 'removed_features',
                      'custom_max_users', 'custom_max_items',
                      'custom_max_transactions', 'custom_max_branches')
        ):
            super().save_model(request, obj, form, change)
            SubscriptionEvent.objects.create(
                subscription=obj,
                event_type='note',
                old_value='',
                new_value='feature/limit override updated',
                performed_by=request.user.phone_number,
                note='Feature overrides or custom limits changed via admin form',
            )
        else:
            super().save_model(request, obj, form, change)

    # ── List columns ─────────────────────────────────────────────────────────

    @admin.display(description='Organisation', ordering='organization__name')
    def organization_link(self, obj):
        return format_html(
            '<a href="/admin/authapp/organization/{}/change/"><b>{}</b></a>',
            obj.organization_id, obj.organization.name,
        )

    @admin.display(description='Plan', ordering='plan')
    def plan_badge(self, obj):
        return _badge(obj.get_plan_display(), PLAN_COLORS.get(obj.plan, '#6B7280'))

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj):
        obj.refresh_status()
        return _badge(obj.get_status_display(), STATUS_COLORS.get(obj.status, '#6B7280'))

    @admin.display(description='Trial left')
    def trial_days_left(self, obj):
        if obj.plan != 'trial' or not obj.trial_ends_at:
            return '—'
        days = (obj.trial_ends_at - timezone.now()).days
        if days < 0:
            return format_html('<span style="color:#EF4444;font-weight:700">Expired</span>')
        color = '#EF4444' if days <= 3 else '#F59E0B' if days <= 7 else '#10B981'
        return format_html('<span style="color:{};font-weight:600">{}&nbsp;days</span>', color, days)

    @admin.display(description='Users')
    def usage_users(self, obj):
        return obj.organization.users.filter(is_active=True).count()

    @admin.display(description='Items')
    def usage_items(self, obj):
        try:
            from inventory.models import Item
            return Item.objects.filter(organization=obj.organization, status='active').count()
        except Exception:
            return '—'

    @admin.display(description='Trans/mo')
    def usage_transactions(self, obj):
        try:
            from pos.models import Sale
            start = timezone.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            return Sale.objects.filter(organization=obj.organization, created__gte=start).count()
        except Exception:
            return '—'

    # ── Change-form readonly panels ──────────────────────────────────────────

    @admin.display(description='Summary')
    def subscription_summary(self, obj):
        """Top-of-form status card."""
        try:
            obj.refresh_status()
            plan_c   = PLAN_COLORS.get(obj.plan, '#6B7280')
            status_c = STATUS_COLORS.get(obj.status, '#6B7280')
            plan_lbl  = conditional_escape(obj.get_plan_display())
            stat_lbl  = conditional_escape(obj.get_status_display())

            trial_html = ''
            if obj.plan == 'trial' and obj.trial_ends_at:
                days = (obj.trial_ends_at - timezone.now()).days
                dc   = '#EF4444' if days < 0 else '#F59E0B' if days <= 7 else '#10B981'
                label = 'Expired' if days < 0 else f'{max(days,0)} days remaining'
                trial_html = (
                    f'<div style="margin-top:8px;font-size:12px;color:#94a3b8">'
                    f'Trial ends: <strong style="color:{dc}">'
                    f'{obj.trial_ends_at.strftime("%d %b %Y %H:%M")} UTC'
                    f'</strong> &nbsp;·&nbsp; <span style="color:{dc}">{label}</span>'
                    f'</div>'
                )

            period_html = ''
            if obj.current_period_end:
                period_html = (
                    f'<div style="margin-top:4px;font-size:12px;color:#94a3b8">'
                    f'Billing period ends: <strong style="color:#e2e8f0">'
                    f'{obj.current_period_end.strftime("%d %b %Y")}'
                    f'</strong></div>'
                )

            price_html = ''
            try:
                pp = PlanPricing.objects.get(plan=obj.plan)
                is_annual = obj.billing_cycle == 'annual'
                if is_annual and float(pp.annual_price) > 0:
                    effective_monthly = float(pp.annual_price) / 12
                    savings = pp.annual_savings_pct
                    savings_badge = (
                        f'<span style="background:#10B981;color:#fff;'
                        f'padding:1px 6px;border-radius:8px;font-size:10px;margin-left:4px">'
                        f'Save {savings}%</span>'
                    ) if savings > 0 else ''
                    price_html = (
                        f'<span style="font-size:12px;color:#94a3b8;margin-left:12px">'
                        f'{pp.currency} {float(pp.annual_price):.2f}/yr '
                        f'<span style="color:#64748b">(≈ {pp.currency} {effective_monthly:.2f}/mo)</span>'
                        f'{savings_badge}</span>'
                    )
                elif float(pp.monthly_price) > 0:
                    savings = pp.annual_savings_pct
                    annual_hint = (
                        f' &nbsp;<span style="background:rgba(16,185,129,0.15);color:#10b981;'
                        f'border:1px solid rgba(16,185,129,0.3);'
                        f'padding:1px 6px;border-radius:8px;font-size:10px">'
                        f'Save {savings}% annually</span>'
                    ) if savings > 0 else ''
                    price_html = (
                        f'<span style="font-size:12px;color:#94a3b8;margin-left:12px">'
                        f'{pp.currency} {float(pp.monthly_price):.2f}/mo{annual_hint}</span>'
                    )
            except PlanPricing.DoesNotExist:
                pass

            cycle = obj.billing_cycle or 'monthly'
            cycle_icon = '📅' if cycle == 'annual' else '🗓'
            cycle_color = '#10B981' if cycle == 'annual' else '#64748b'
            cycle_label = conditional_escape(cycle.title())
            cycle_html = (
                f'<span style="font-size:11px;color:{cycle_color};'
                f'background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.1);'
                f'padding:3px 10px;border-radius:10px;margin-left:6px">'
                f'{cycle_icon} {cycle_label} billing</span>'
            ) if obj.plan != 'trial' else ''

            html = (
                f'<div style="background:linear-gradient(135deg,#1e293b,#0f172a);'
                f'border:1px solid rgba(255,255,255,0.1);border-radius:12px;'
                f'padding:16px 20px;margin-bottom:4px">'
                f'<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">'
                f'<span style="background:{plan_c};color:#fff;padding:4px 14px;'
                f'border-radius:20px;font-size:13px;font-weight:700">{plan_lbl}</span>'
                f'<span style="background:{status_c};color:#fff;padding:4px 14px;'
                f'border-radius:20px;font-size:13px;font-weight:700">{stat_lbl}</span>'
                f'{cycle_html}'
                f'{price_html}'
                f'</div>'
                f'{trial_html}'
                f'{period_html}'
                f'</div>'
            )
            return mark_safe(html)
        except Exception as exc:
            return format_html('<span style="color:#EF4444">Error: {}</span>', str(exc))

    @admin.display(description='Plan Features & Limits')
    def plan_features_panel(self, obj):
        try:
            features = PLAN_FEATURES.get(obj.plan, [])
            limits   = PLAN_LIMITS.get(obj.plan, {})
            plan_c   = PLAN_COLORS.get(obj.plan, '#6B7280')

            def _limit(v):
                return '∞' if v == -1 else f'{v:,}'

            limits_html = (
                f'<div style="display:flex;gap:20px;margin-bottom:14px;flex-wrap:wrap">'
                f'<span style="background:rgba(255,255,255,0.06);padding:6px 14px;'
                f'border-radius:8px;font-size:12px">'
                f'<span style="color:#94a3b8">Users&nbsp;</span>'
                f'<strong style="color:#e2e8f0">{_limit(limits.get("users",-1))}</strong></span>'
                f'<span style="background:rgba(255,255,255,0.06);padding:6px 14px;'
                f'border-radius:8px;font-size:12px">'
                f'<span style="color:#94a3b8">Items&nbsp;</span>'
                f'<strong style="color:#e2e8f0">{_limit(limits.get("items",-1))}</strong></span>'
                f'<span style="background:rgba(255,255,255,0.06);padding:6px 14px;'
                f'border-radius:8px;font-size:12px">'
                f'<span style="color:#94a3b8">Trans/mo&nbsp;</span>'
                f'<strong style="color:#e2e8f0">{_limit(limits.get("transactions",-1))}</strong></span>'
                f'</div>'
            )

            rows = ''.join(
                f'<div style="padding:4px 0;font-size:13px;color:'
                f'{"#e2e8f0" if icon == "✅" else "#64748b"}">'
                f'{icon}&nbsp; {feat}</div>'
                for icon, feat in features
            )

            html = (
                f'<div style="border-left:3px solid {plan_c};padding-left:14px">'
                f'{limits_html}{rows}</div>'
            )
            return mark_safe(html)
        except Exception as exc:
            return format_html('<span style="color:#EF4444">Error: {}</span>', str(exc))

    @admin.display(description='Effective Feature Set (preview)')
    def feature_override_panel(self, obj):
        """
        Read-only panel showing which features are effectively active for this org
        after applying extra_features and removed_features overrides.
        """
        try:
            # All feature keys + labels — read from DB (canonical order), fallback to hardcoded
            matrix = PlanFeatureFlag.get_all_features_matrix()
            label_map = matrix['feature_labels']
            all_features = [(k, label_map.get(k, k)) for k in matrix['feature_order']]
            if not all_features:
                all_features = list(FEATURE_KEY_CHOICES)

            # Plan baseline features — read from DB (falls back to hardcoded if empty)
            base     = PlanFeatureFlag.get_features_for_plan(obj.plan)
            extra    = set(obj.extra_features or [])
            removed  = set(obj.removed_features or [])
            effective = (base | extra) - removed

            rows = []
            for key, label in all_features:
                in_plan   = key in base
                is_extra  = key in extra
                is_removed = key in removed
                enabled   = key in effective

                if is_extra:
                    icon    = '✅'
                    suffix  = ' <span style="background:#0D9488;color:#fff;padding:1px 7px;border-radius:8px;font-size:10px;font-weight:700">+added</span>'
                    color   = '#e2e8f0'
                elif is_removed:
                    icon    = '🚫'
                    suffix  = ' <span style="background:#EF4444;color:#fff;padding:1px 7px;border-radius:8px;font-size:10px;font-weight:700">−removed</span>'
                    color   = '#64748b'
                elif in_plan:
                    icon    = '✅'
                    suffix  = ' <span style="color:#475569;font-size:10px">plan default</span>'
                    color   = '#e2e8f0'
                else:
                    icon    = '⬜'
                    suffix  = ''
                    color   = '#334155'

                rows.append(
                    f'<div style="padding:3px 0;font-size:13px;color:{color}">'
                    f'{icon}&nbsp; {label}{suffix}</div>'
                )

            custom_limits_html = ''
            overrides = [
                ('Max users',         obj.custom_max_users),
                ('Max items',         obj.custom_max_items),
                ('Max transactions',  obj.custom_max_transactions),
                ('Max branches',      obj.custom_max_branches),
            ]
            has_custom = any(v is not None for _, v in overrides)
            if has_custom:
                limit_rows = ''.join(
                    f'<span style="background:rgba(255,255,255,0.07);padding:5px 12px;'
                    f'border-radius:8px;font-size:12px;margin:3px">'
                    f'<span style="color:#94a3b8">{label}&nbsp;</span>'
                    f'<strong style="color:#0D9488">{"∞" if v == -1 else v}</strong></span>'
                    for label, v in overrides if v is not None
                )
                custom_limits_html = (
                    f'<div style="margin-top:12px;padding-top:10px;'
                    f'border-top:1px solid rgba(255,255,255,0.08)">'
                    f'<div style="font-size:11px;color:#64748b;margin-bottom:6px;font-weight:600">'
                    f'CUSTOM LIMIT OVERRIDES</div>'
                    f'<div style="display:flex;flex-wrap:wrap;gap:4px">{limit_rows}</div>'
                    f'</div>'
                )

            html = (
                f'<div style="border-left:3px solid #0D9488;padding-left:14px">'
                f'{"".join(rows)}'
                f'{custom_limits_html}'
                f'</div>'
            )
            return mark_safe(html)
        except Exception as exc:
            return format_html('<span style="color:#EF4444">Error: {}</span>', str(exc))

    @admin.display(description='Live Usage')
    def live_usage_panel(self, obj):
        try:
            usage  = obj._usage()
            limits = PLAN_LIMITS.get(obj.plan, {})

            def row(icon, label, val, max_val):
                lbl   = f'/ {max_val:,}' if max_val != -1 else '/ ∞'
                pct   = min(int(val / max_val * 100), 100) if max_val > 0 else 0
                bc    = '#EF4444' if pct >= 100 else '#F59E0B' if pct >= 80 else '#10B981'
                bar   = (
                    f'<div style="background:#2d3748;border-radius:4px;height:6px;'
                    f'width:140px;display:inline-block;vertical-align:middle">'
                    f'<div style="background:{bc};width:{pct}%;height:100%;border-radius:4px"></div>'
                    f'</div>'
                ) if max_val != -1 else ''
                return (
                    f'<tr>'
                    f'<td style="padding:5px 14px 5px 0;color:#94a3b8;white-space:nowrap">{icon} {label}</td>'
                    f'<td style="padding:5px 14px;font-weight:600;color:#e2e8f0;white-space:nowrap">'
                    f'{val} <span style="color:#64748b;font-weight:400">{lbl}</span></td>'
                    f'<td style="padding:5px 0">{bar}</td>'
                    f'</tr>'
                )

            html = (
                '<table style="border-collapse:collapse;font-size:13px">'
                + row('👤', 'Active Users',    usage['users_count'],             limits.get('users', -1))
                + row('💊', 'Inventory Items', usage['items_count'],             limits.get('items', -1))
                + row('🧾', 'Transactions/mo', usage['transactions_this_month'], limits.get('transactions', -1))
                + '</table>'
            )
            return mark_safe(html)
        except Exception as exc:
            return format_html('<span style="color:#EF4444">Error loading usage: {}</span>', str(exc))


# ── Plan Pricing Admin ────────────────────────────────────────────────────────

@admin.register(PlanPricing)
class PlanPricingAdmin(admin.ModelAdmin):
    """
    Custom pricing editor — shows all four plans in a single card grid.
    Superusers can edit monthly price, annual price, currency and active flag
    for every plan on one page, then save everything with a single button.
    """
    changelist_template = 'admin/subscription/planpricing/changelist.html'

    # ── Permissions ────────────────────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return False   # managed via the editor, not the standard add form

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return False   # plan prices are never deleted

    # ── Custom changelist ──────────────────────────────────────────────────

    def changelist_view(self, request, extra_context=None):
        if not request.user.is_superuser:
            raise PermissionDenied

        if request.method == 'POST':
            action = request.POST.get('_pricing_action')
            if action == 'save':
                return self._save_prices(request)
            if action == 'reset':
                return self._reset_prices(request)

        # Ensure all 4 plan rows exist
        PlanPricing.ensure_defaults()

        pricing_qs = {pp.plan: pp for pp in PlanPricing.objects.all()}
        plan_data  = []
        for plan, label in PLAN_CHOICES:
            pp = pricing_qs.get(plan)
            plan_data.append({
                'plan':          plan,
                'label':         label,
                'color':         PLAN_COLORS.get(plan, '#6B7280'),
                'pp':            pp,
                'default_price': PLAN_PRICES.get(plan, 0),
                'currencies':    SUPPORTED_CURRENCIES,
            })

        extra_context = extra_context or {}
        extra_context.update({
            'title':      'Plan Pricing Editor',
            'plan_data':  plan_data,
            'currencies': SUPPORTED_CURRENCIES,
        })
        return super().changelist_view(request, extra_context)

    # ── POST handlers ──────────────────────────────────────────────────────

    def _save_prices(self, request):
        updated = []
        errors  = []
        actor   = request.user.phone_number

        for plan, _label in PLAN_CHOICES:
            try:
                monthly  = Decimal(request.POST.get(f'monthly_{plan}',  '0').strip())
                annual   = Decimal(request.POST.get(f'annual_{plan}',   '0').strip())
                currency = request.POST.get(f'currency_{plan}', 'USD').strip().upper()[:3]
                is_active = f'active_{plan}' in request.POST

                if monthly < 0:
                    raise ValueError('Price cannot be negative.')
                if annual < 0:
                    raise ValueError('Annual price cannot be negative.')
                if currency not in SUPPORTED_CURRENCIES:
                    currency = 'USD'

                pp, _ = PlanPricing.objects.get_or_create(plan=plan)
                old_monthly = pp.monthly_price

                pp.monthly_price = monthly
                pp.annual_price  = annual
                pp.currency      = currency
                pp.is_active     = is_active
                pp.updated_by    = actor
                pp.save()

                if pp.monthly_price != old_monthly:
                    SubscriptionEvent.objects.bulk_create([
                        SubscriptionEvent(
                            subscription=sub,
                            event_type='note',
                            old_value=f'{plan} price was {old_monthly}',
                            new_value=f'{plan} price now {monthly}',
                            performed_by=actor,
                            note='Price updated by admin',
                        )
                        for sub in Subscription.objects.filter(plan=plan)
                    ])

                updated.append(_label)

            except (InvalidOperation, ValueError) as exc:
                errors.append(f'{_label}: {exc}')

        if errors:
            for err in errors:
                self.message_user(request, err, messages.ERROR)
        else:
            self.message_user(
                request,
                f'Prices saved for: {", ".join(updated)}.',
                messages.SUCCESS,
            )
        return HttpResponseRedirect(
            reverse('admin:subscription_planpricing_changelist')
        )

    def _reset_prices(self, request):
        actor = request.user.phone_number
        for plan, price in PLAN_PRICES.items():
            PlanPricing.objects.filter(plan=plan).update(
                monthly_price=Decimal(str(price)),
                updated_by=actor,
            )
        self.message_user(
            request,
            'All prices reset to default values.',
            messages.SUCCESS,
        )
        return HttpResponseRedirect(
            reverse('admin:subscription_planpricing_changelist')
        )


# ── Plan Feature Flags Admin ──────────────────────────────────────────────────

@admin.register(PlanFeatureFlag)
class PlanFeatureFlagAdmin(admin.ModelAdmin):
    """
    Matrix editor for plan features.
    Superusers can add, remove, rename, reorder, and toggle features per plan.
    Changes take effect immediately — Flutter reads the feature matrix from the
    subscription API on every app launch.

    Matrix view (changelist): rows = features, columns = plans, cells = on/off.
    Standard change form: edit a single (plan, feature_key) row in detail.
    """

    changelist_template = 'admin/subscription/planfeatureflag/changelist.html'

    list_display  = ('feature_label', 'feature_key', 'plan_badge', 'enabled_badge', 'sort_order')
    list_filter   = ('plan', 'is_enabled')
    search_fields = ('feature_key', 'feature_label')
    list_editable = ('sort_order',)
    ordering      = ('sort_order', 'plan', 'feature_key')

    fieldsets = (
        (None, {
            'fields': (('plan', 'feature_key'), 'feature_label', 'is_enabled', 'sort_order'),
            'description': (
                'Each row controls whether a feature is included in a plan. '
                'The <strong>feature_key</strong> must match the key used in the '
                'Flutter app (e.g. <code>wholesale</code>, <code>advanced_reports</code>). '
                'The <strong>feature_label</strong> is the human-readable name shown in '
                'the in-app subscription screen. '
                'Changes are live immediately after saving.'
            ),
        }),
    )

    # ── Permissions ───────────────────────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser

    # ── List columns ──────────────────────────────────────────────────────────

    @admin.display(description='Plan', ordering='plan')
    def plan_badge(self, obj):
        return _badge(obj.get_plan_display(), PLAN_COLORS.get(obj.plan, '#6B7280'))

    @admin.display(description='Enabled', ordering='is_enabled', boolean=False)
    def enabled_badge(self, obj):
        if obj.is_enabled:
            return format_html(
                '<span style="background:#10B981;color:#fff;padding:2px 10px;'
                'border-radius:10px;font-size:11px;font-weight:600">Enabled</span>'
            )
        return format_html(
            '<span style="background:#EF4444;color:#fff;padding:2px 10px;'
            'border-radius:10px;font-size:11px;font-weight:600">Disabled</span>'
        )

    # ── Custom changelist (matrix view) ──────────────────────────────────────

    def changelist_view(self, request, extra_context=None):
        if not request.user.is_superuser:
            raise PermissionDenied

        # Handle POST: save matrix toggles
        if request.method == 'POST' and '_matrix_save' in request.POST:
            return self._save_matrix(request)

        # Handle POST: reset to defaults
        if request.method == 'POST' and '_matrix_reset' in request.POST:
            return self._reset_matrix(request)

        # Handle POST: add new feature row
        if request.method == 'POST' and '_add_feature' in request.POST:
            return self._add_feature_row(request)

        # Handle POST: delete all flags for one feature key
        if request.method == 'POST' and '_delete_feature' in request.POST:
            return self._delete_feature_row(request)

        # Handle POST: additive sync from PLAN_FEATURES_DEFAULT
        if request.method == 'POST' and '_sync_defaults' in request.POST:
            return self._sync_defaults_handler(request)

        # Seed if empty
        PlanFeatureFlag.ensure_defaults()

        # Build matrix data: rows = all known feature keys, columns = plans
        all_keys     = [k for k, _ in FEATURE_KEY_CHOICES]
        label_map    = dict(FEATURE_KEY_CHOICES)
        plan_list    = [p for p, _ in PLAN_CHOICES]
        plan_labels  = dict(PLAN_CHOICES)

        # Fetch all flags
        flag_map = {}
        for flag in PlanFeatureFlag.objects.all():
            flag_map[(flag.plan, flag.feature_key)] = flag

        # Build row objects
        rows = []
        seen_keys = set(all_keys)
        for key, default_label in FEATURE_KEY_CHOICES:
            row = {
                'key':    key,
                'label':  label_map.get(key, key),
                'sort':   min(
                    (flag_map.get((p, key)).sort_order for p in plan_list
                     if (p, key) in flag_map),
                    default=FEATURE_KEY_CHOICES.index((key, default_label))
                    if (key, default_label) in FEATURE_KEY_CHOICES else 99,
                ),
                'cells':  {},
            }
            for plan in plan_list:
                flag = flag_map.get((plan, key))
                row['cells'][plan] = flag.is_enabled if flag else False
            rows.append(row)

        # Include any DB-only (custom) feature keys not in FEATURE_KEY_CHOICES
        custom_keys = (
            PlanFeatureFlag.objects
            .exclude(feature_key__in=all_keys)
            .values_list('feature_key', 'feature_label')
            .distinct()
        )
        for key, label in custom_keys:
            if key in seen_keys:
                continue
            seen_keys.add(key)
            row = {'key': key, 'label': label, 'sort': 99, 'cells': {}}
            for plan in plan_list:
                flag = flag_map.get((plan, key))
                row['cells'][plan] = flag.is_enabled if flag else False
            rows.append(row)

        rows.sort(key=lambda r: r['sort'])

        extra_context = extra_context or {}
        extra_context.update({
            'title':        'Plan Feature Matrix',
            'plan_list':    plan_list,
            'plan_labels':  plan_labels,
            'plan_colors':  PLAN_COLORS,
            'rows':         rows,
            'all_feature_key_choices': FEATURE_KEY_CHOICES,
        })
        return super().changelist_view(request, extra_context)

    # ── POST handlers ─────────────────────────────────────────────────────────

    def _save_matrix(self, request):
        """Save checkbox toggles, label edits, and sort-order changes from the matrix form."""
        saved = 0
        label_map = dict(FEATURE_KEY_CHOICES)

        # Collect all feature keys currently tracked
        all_keys = set(PlanFeatureFlag.objects.values_list('feature_key', flat=True))
        all_keys.update(k for k, _ in FEATURE_KEY_CHOICES)

        for key in all_keys:
            custom_label = request.POST.get(f'label_{key}', '').strip()
            sort_str     = request.POST.get(f'sort_{key}', '').strip()
            try:
                new_sort = int(sort_str)
            except (ValueError, TypeError):
                new_sort = None  # no sort change submitted

            for plan, _ in PLAN_CHOICES:
                field_name = f'feat_{plan}_{key}'
                is_checked = field_name in request.POST
                obj, created = PlanFeatureFlag.objects.get_or_create(
                    plan=plan,
                    feature_key=key,
                    defaults={
                        'feature_label': custom_label or label_map.get(key, key),
                        'is_enabled':    is_checked,
                        'sort_order':    new_sort if new_sort is not None else 0,
                    },
                )
                if not created:
                    changed = False
                    if obj.is_enabled != is_checked:
                        obj.is_enabled = is_checked
                        changed = True
                    if custom_label and obj.feature_label != custom_label:
                        obj.feature_label = custom_label
                        changed = True
                    if new_sort is not None and obj.sort_order != new_sort:
                        obj.sort_order = new_sort
                        changed = True
                    if changed:
                        obj.save()
                        saved += 1
                else:
                    saved += 1

        self.message_user(
            request,
            f'Feature matrix saved ({saved} flag(s) updated). '
            f'The Flutter app will pick up changes on next subscription load.',
            messages.SUCCESS,
        )
        return HttpResponseRedirect(
            reverse('admin:subscription_planfeatureflag_changelist')
        )

    def _add_feature_row(self, request):
        """Add a new custom feature key to the matrix."""
        key   = request.POST.get('new_key',   '').strip().lower().replace(' ', '_')
        label = request.POST.get('new_label', '').strip()

        if not key or not label:
            self.message_user(request, 'Key and label are required.', messages.ERROR)
            return HttpResponseRedirect(
                reverse('admin:subscription_planfeatureflag_changelist')
            )

        if PlanFeatureFlag.objects.filter(feature_key=key).exists():
            self.message_user(
                request,
                f'Feature key "{key}" already exists — edit it in the matrix below.',
                messages.WARNING,
            )
            return HttpResponseRedirect(
                reverse('admin:subscription_planfeatureflag_changelist')
            )

        # Add as disabled for all plans by default; admin can toggle on
        for plan, _ in PLAN_CHOICES:
            PlanFeatureFlag.objects.create(
                plan=plan,
                feature_key=key,
                feature_label=label,
                is_enabled=False,
                sort_order=99,
            )

        self.message_user(
            request,
            f'Feature "{label}" ({key}) added to all plans as disabled. '
            f'Toggle it on for the plans you want.',
            messages.SUCCESS,
        )
        return HttpResponseRedirect(
            reverse('admin:subscription_planfeatureflag_changelist')
        )

    def _reset_matrix(self, request):
        """Delete all flags and re-seed from PLAN_FEATURES_DEFAULT."""
        PlanFeatureFlag.objects.all().delete()
        PlanFeatureFlag.ensure_defaults()
        self.message_user(
            request,
            'Feature matrix reset to system defaults.',
            messages.SUCCESS,
        )
        return HttpResponseRedirect(
            reverse('admin:subscription_planfeatureflag_changelist')
        )

    def _delete_feature_row(self, request):
        """Remove all PlanFeatureFlag rows for the given feature key from every plan."""
        key = request.POST.get('delete_key', '').strip()
        if not key:
            self.message_user(request, 'No feature key provided.', messages.ERROR)
            return HttpResponseRedirect(
                reverse('admin:subscription_planfeatureflag_changelist')
            )

        count, _ = PlanFeatureFlag.objects.filter(feature_key=key).delete()
        if count:
            self.message_user(
                request,
                f'Feature "{key}" removed from all plans ({count} flag(s) deleted). '
                f'The Flutter app will no longer see this feature.',
                messages.SUCCESS,
            )
        else:
            self.message_user(
                request,
                f'Feature key "{key}" was not found in the database.',
                messages.WARNING,
            )
        return HttpResponseRedirect(
            reverse('admin:subscription_planfeatureflag_changelist')
        )

    def _sync_defaults_handler(self, request):
        """
        Additive sync: adds every (plan, feature_key) pair from PLAN_FEATURES_DEFAULT
        that is currently missing from the DB.  Existing rows (including any superuser
        customisations) are left completely untouched — nothing is removed or disabled.
        Covers all plans and all features.
        """
        result  = PlanFeatureFlag.sync_defaults()
        added   = result['added']
        already = result['already_present']

        if added:
            self.message_user(
                request,
                f'Sync complete: {added} missing flag(s) added across all plans. '
                f'{already} flag(s) were already present and left unchanged. '
                f'Flutter will pick up changes on the next subscription load.',
                messages.SUCCESS,
            )
        else:
            self.message_user(
                request,
                f'Already up to date — all {already} default flag(s) are present. '
                f'No changes were made.',
                messages.SUCCESS,
            )
        return HttpResponseRedirect(
            reverse('admin:subscription_planfeatureflag_changelist')
        )
