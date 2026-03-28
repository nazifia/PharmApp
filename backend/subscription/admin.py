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
from django.utils.html import format_html
from django.utils.safestring import mark_safe

from .models import (
    PLAN_CHOICES, PLAN_FEATURES, PLAN_LIMITS, PLAN_PRICES, SUPPORTED_CURRENCIES,
    PlanPricing, Subscription, SubscriptionEvent,
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
        sub.plan = 'trial'; sub.status = 'trial'
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
        'subscription_summary',
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
                ('trial_ends_at', 'current_period_end'),
                'external_subscription_id',
            ),
            'description': (
                'Changing <strong>Plan</strong> to a paid tier auto-sets status '
                'to <em>Active</em> and clears the trial date. '
                'Changing to <em>Trial</em> recalculates status from the trial end date.'
            ),
        }),
        # Tab: plan-features-tab
        ('Plan Features', {
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

        # ── Activate a specific paid plan ─────────────────────────────────
        if action in ('activate_starter', 'activate_professional', 'activate_enterprise'):
            plan_map = {
                'activate_starter':      'starter',
                'activate_professional': 'professional',
                'activate_enterprise':   'enterprise',
            }
            new_plan = plan_map[action]
            old_plan = obj.plan
            obj.plan          = new_plan
            obj.status        = 'active'
            obj.trial_ends_at = None
            obj.save()
            SubscriptionEvent.objects.create(
                subscription=obj, event_type='activated',
                old_value=old_plan, new_value=new_plan,
                performed_by=actor, note=note,
            )
            return _redirect(
                f"Subscription activated on {new_plan.title()} plan."
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
            plan_lbl  = obj.get_plan_display()
            stat_lbl  = obj.get_status_display()

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
                pp    = PlanPricing.objects.get(plan=obj.plan)
                price = float(pp.monthly_price)
                if price > 0:
                    savings = pp.annual_savings_pct
                    annual_hint = (
                        f' &nbsp;<span style="background:#10B981;color:#fff;'
                        f'padding:1px 6px;border-radius:8px;font-size:10px">'
                        f'Save {savings}% annually</span>'
                    ) if savings > 0 else ''
                    price_html = (
                        f'<span style="font-size:12px;color:#94a3b8;margin-left:12px">'
                        f'{pp.currency} {price:.2f}/mo{annual_hint}</span>'
                    )
            except PlanPricing.DoesNotExist:
                pass

            html = (
                f'<div style="background:linear-gradient(135deg,#1e293b,#0f172a);'
                f'border:1px solid rgba(255,255,255,0.1);border-radius:12px;'
                f'padding:16px 20px;margin-bottom:4px">'
                f'<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">'
                f'<span style="background:{plan_c};color:#fff;padding:4px 14px;'
                f'border-radius:20px;font-size:13px;font-weight:700">{plan_lbl}</span>'
                f'<span style="background:{status_c};color:#fff;padding:4px 14px;'
                f'border-radius:20px;font-size:13px;font-weight:700">{stat_lbl}</span>'
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
