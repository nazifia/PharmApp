import json

from django import forms
from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.forms import UserChangeForm, UserCreationForm
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404, render
from django.utils.html import conditional_escape, format_html, mark_safe
from django.urls import path, reverse
from django.db import transaction
from django.db.models import Count, Max, Q

from .admin_mixins import OrgScopedAdminMixin
from .backup_views import backup_http_response, restore_org_backup
from .utils import normalize_ng_phone
from .models import (
    ActivityLog, CommissionConfig, Organization,
    PharmUser, PharmacyNetwork, PharmacyNetworkMembership,
    SiteConfig, UserPermissionOverride,
)
from branches.admin import BranchInline

# ── Role metadata ──────────────────────────────────────────────────────────────

ROLE_COLORS = {
    'Admin':                '#EF4444',
    'Manager':              '#8B5CF6',
    'Pharmacist':           '#0D9488',
    'Pharm-Tech':           '#06B6D4',
    'Salesperson':          '#F59E0B',
    'Cashier':              '#10B981',
    'Wholesale Manager':    '#3B82F6',
    'Wholesale Operator':   '#6366F1',
    'Wholesale Salesperson':'#64748B',
}

# permission_key → (label, allowed_roles_set)
_PERM_MATRIX = [
    ('Reports & Analytics',   {'Admin', 'Manager'}),
    ('User Management',       {'Admin', 'Manager'}),
    ('System Settings',       {'Admin', 'Manager'}),
    ('Notifications',         {'Admin', 'Manager'}),
    ('Subscription',          {'Admin', 'Manager'}),
    ('Retail POS',            {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Salesperson', 'Cashier'}),
    ('Wholesale POS',         {'Admin', 'Manager', 'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson'}),
    ('Inventory — Read',      {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Salesperson', 'Cashier',
                               'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson'}),
    ('Inventory — Write',     {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'}),
    ('Customers — Read',      {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Salesperson', 'Cashier',
                               'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson'}),
    ('Customers — Write',     {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Wholesale Manager'}),
    ('Expenses',              {'Admin', 'Manager', 'Wholesale Manager'}),
    ('Suppliers',             {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'}),
    ('Payment Requests',      {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'}),
    ('Stock Transfers',       {'Admin', 'Manager', 'Wholesale Manager', 'Wholesale Operator'}),
    ('Wholesale View',        {'Admin', 'Manager', 'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson'}),
    ('Inventory — Create',   {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'}),
    ('Prescriptions — Read', {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech'}),
    ('Prescriptions — Write',{'Admin', 'Manager', 'Pharmacist'}),
    ('Low Stock Alert Edit',  {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'}),
]

# Maps the label from _PERM_MATRIX to the permission key used in overrides
_PERM_LABEL_TO_KEY = {
    'Reports & Analytics':   'viewReports',
    'User Management':       'manageUsers',
    'System Settings':       'manageSettings',
    'Notifications':         'viewNotifications',
    'Subscription':          'viewSubscription',
    'Retail POS':            'retailPOS',
    'Wholesale POS':         'wholesalePOS',
    'Inventory — Read':      'readInventory',
    'Inventory — Write':     'writeInventory',
    'Customers — Read':      'readCustomers',
    'Customers — Write':     'writeCustomers',
    'Expenses':              'manageExpenses',
    'Suppliers':             'manageSuppliers',
    'Payment Requests':      'processPayments',
    'Stock Transfers':       'manageTransfers',
    'Wholesale View':        'viewWholesale',
    'Inventory — Create':   'createInventory',
    'Prescriptions — Read': 'readPrescriptions',
    'Prescriptions — Write':'writePrescriptions',
    'Low Stock Alert Edit':  'editLowStockAlert',
}

# Roles whose is_wholesale_operator flag should be True automatically
_WHOLESALE_ROLES = {'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson'}


# ── Organisation ──────────────────────────────────────────────────────────────

def _subscription_inline():
    """Lazily import the inline to avoid circular imports at module load."""
    try:
        from subscription.admin import SubscriptionInline
        return [SubscriptionInline]
    except ImportError:
        return []


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    """Visible and editable by superusers only."""

    list_display  = ["name", "slug", "phone", "user_count", "auto_logout_minutes", "subscription_plan", "subscription_status", "last_activity", "last_reminded", "backup_links", "created_at"]
    list_editable = ["auto_logout_minutes"]
    search_fields = ["name", "slug", "phone"]
    readonly_fields = ["slug", "created_at", "user_count", "last_reminded_at"]
    ordering = ["name"]
    inlines  = []   # populated in get_inlines()
    actions  = ["show_delete_impact"]
    list_select_related = ["subscription"]

    def get_queryset(self, request):
        # select_related avoids a subscription query per row; annotate avoids a
        # COUNT per row for the Users column.
        return super().get_queryset(request).annotate(
            _user_count=Count("users", distinct=True),
            _last_activity=Max("users__last_login"),
        )

    def get_inlines(self, request, obj):
        inlines = list(_subscription_inline())
        if obj is not None:
            inlines.append(BranchInline)
        return inlines

    def save_formset(self, request, form, formset, change):
        """
        Auto-set current_period_end when a subscription is approved (status → active).
        Monthly plan  → +30 days.
        Annual plan   → +365 days.
        """
        instances = formset.save(commit=False)
        auto_set = []
        for obj in instances:
            if (
                hasattr(obj, 'billing_cycle')
                and hasattr(obj, 'status')
                and hasattr(obj, 'plan')
            ):
                if obj.status == 'active' and obj.plan != 'trial' and not obj.current_period_end:
                    try:
                        from subscription.admin import _calc_period_end
                        obj.current_period_end = _calc_period_end(obj.billing_cycle)
                        auto_set.append(obj)
                    except ImportError:
                        pass
            obj.save()
        formset.save_m2m()
        for obj in formset.deleted_objects:
            obj.delete()
        if auto_set:
            sub = auto_set[0]
            cycle_label = 'annually' if sub.billing_cycle == 'annual' else 'monthly'
            self.message_user(
                request,
                (
                    f"✅ Subscription approved: {sub.get_plan_display()} plan "
                    f"({cycle_label}). Period ends {sub.current_period_end.strftime('%d %b %Y')}."
                ),
                messages.SUCCESS,
            )

    @admin.display(description='Plan')
    def subscription_plan(self, obj):
        try:
            sub = obj.subscription
            colors = {
                'trial':        '#F59E0B',
                'starter':      '#3B82F6',
                'professional': '#8B5CF6',
                'enterprise':   '#06B6D4',
            }
            c = colors.get(sub.plan, '#6B7280')
            return format_html(
                '<span style="background:{};color:#fff;padding:2px 8px;'
                'border-radius:10px;font-size:11px">{}</span>',
                c, sub.get_plan_display(),
            )
        except Exception:
            return format_html('<span style="color:#64748b;font-size:11px">—</span>')

    @admin.display(description='Status')
    def subscription_status(self, obj):
        try:
            sub = obj.subscription
            colors = {
                'trial':     '#3B82F6',
                'expiring':  '#F59E0B',
                'expired':   '#EF4444',
                'active':    '#10B981',
                'pending':   '#8B5CF6',
                'suspended': '#DC2626',
                'cancelled': '#6B7280',
            }
            c = colors.get(sub.status, '#6B7280')
            label = sub.get_status_display()
            return format_html(
                '<span style="background:{};color:#fff;padding:2px 8px;'
                'border-radius:10px;font-size:11px">{}</span>',
                c, label,
            )
        except Exception:
            return format_html('<span style="color:#64748b;font-size:11px">—</span>')

    @admin.display(description="Users", ordering="_user_count")
    def user_count(self, obj):
        val = getattr(obj, "_user_count", None)
        return val if val is not None else obj.users.count()

    @admin.display(description="Last activity", ordering="_last_activity")
    def last_activity(self, obj):
        from django.utils import timezone
        last = getattr(obj, "_last_activity", None)
        if last is None:
            return format_html('<span style="color:#64748b;font-size:11px">never</span>')
        days = (timezone.now() - last).days
        c = '#EF4444' if days >= 7 else '#10B981'
        return format_html(
            '<span style="color:{};font-size:11px">{} ({}d ago)</span>',
            c, last.strftime('%d %b %Y'), days,
        )

    @admin.display(description="Last reminded", ordering="last_reminded_at")
    def last_reminded(self, obj):
        if obj.last_reminded_at is None:
            return format_html('<span style="color:#64748b;font-size:11px">—</span>')
        return format_html(
            '<span style="font-size:11px">{}</span>',
            obj.last_reminded_at.strftime('%d %b %Y %H:%M'),
        )

    # ── Backup / Restore ──────────────────────────────────────────────────

    @admin.display(description="Backup")
    def backup_links(self, obj):
        return format_html(
            '<a class="button" style="padding:2px 8px;font-size:11px" href="{}">⬇ Backup</a>&nbsp;'
            '<a class="button" style="padding:2px 8px;font-size:11px" href="{}">⬆ Restore</a>',
            reverse('admin:authapp_organization_backup', args=[obj.pk]),
            reverse('admin:authapp_organization_restore', args=[obj.pk]),
        )

    def get_urls(self):
        custom = [
            path('<int:org_id>/backup/',
                 self.admin_site.admin_view(self.backup_view),
                 name='authapp_organization_backup'),
            path('<int:org_id>/restore/',
                 self.admin_site.admin_view(self.restore_view),
                 name='authapp_organization_restore'),
        ]
        return custom + super().get_urls()

    def backup_view(self, request, org_id):
        if not request.user.is_superuser:
            self.message_user(request, "Only superusers can export org backups.", messages.ERROR)
            return HttpResponseRedirect(reverse('admin:authapp_organization_changelist'))
        org = get_object_or_404(Organization, pk=org_id)
        ActivityLog.objects.create(
            organization=org, user=request.user,
            username=getattr(request.user, 'full_name', '') or request.user.phone_number,
            role=getattr(request.user, 'role', ''),
            action='Backup', category='settings',
            description=f"Superuser exported backup of '{org.name}' via admin site.",
        )
        return backup_http_response(org, exported_by=request.user.phone_number)

    def restore_view(self, request, org_id):
        changelist_url = reverse('admin:authapp_organization_changelist')
        if not request.user.is_superuser:
            self.message_user(request, "Only superusers can restore org backups.", messages.ERROR)
            return HttpResponseRedirect(changelist_url)
        org = get_object_or_404(Organization, pk=org_id)

        if request.method == 'POST':
            upload = request.FILES.get('file')
            if upload is None:
                self.message_user(request, "Choose a backup file first.", messages.ERROR)
            else:
                try:
                    data = json.load(upload)
                    results = restore_org_backup(org, data)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    self.message_user(request, "Invalid backup file: not valid JSON.", messages.ERROR)
                except ValueError as exc:
                    self.message_user(request, str(exc), messages.ERROR)
                else:
                    created = sum(r.get('created', 0) for r in results.values())
                    updated = sum(r.get('updated', 0) for r in results.values())
                    skipped = sum(r.get('skipped', 0) for r in results.values())
                    ActivityLog.objects.create(
                        organization=org, user=request.user,
                        username=getattr(request.user, 'full_name', '') or request.user.phone_number,
                        role=getattr(request.user, 'role', ''),
                        action='Restore', category='settings',
                        description=(
                            f"Superuser restored backup into '{org.name}' via admin site: "
                            f"{created} created, {updated} updated, {skipped} skipped."
                        ),
                    )
                    self.message_user(
                        request,
                        f"Restore into '{org.name}' complete: {created} created, "
                        f"{updated} updated, {skipped} skipped.",
                        messages.SUCCESS,
                    )
                    return HttpResponseRedirect(changelist_url)

        context = {
            **self.admin_site.each_context(request),
            'title': f'Restore backup — {org.name}',
            'org': org,
            'opts': self.model._meta,
        }
        return render(request, 'admin/authapp/organization/restore.html', context)

    # ── Superuser-only permissions ─────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser

    # ── Deletion logic ────────────────────────────────────────────────────

    @admin.action(description="⚠️ Show deletion impact for selected organisations")
    def show_delete_impact(self, request, queryset):
        """Displays a warning message summarising what would be deleted."""
        if not request.user.is_superuser:
            self.message_user(request, "Only superusers can delete organisations.", messages.ERROR)
            return
        lines = []
        for org in queryset:
            impact = self._org_impact(org)
            lines.append(
                f"'{org.name}': {impact['users']} users (will be deactivated), "
                f"{impact['items']} items, {impact['customers']} customers, "
                f"{impact['sales']} sales, {impact['expenses']} expenses, "
                f"{impact['suppliers']} suppliers, {impact['branches']} branches — "
                f"ALL will be permanently deleted."
            )
        self.message_user(
            request,
            mark_safe(
                "<strong>Deletion impact (use the default 'Delete' action to confirm):</strong><br>"
                + "<br>".join(lines)
            ),
            messages.WARNING,
        )

    def _org_impact(self, org):
        """Return a dict of record counts affected by deleting this org."""
        from inventory.models import Item
        from customers.models import Customer
        from pos.models import Sale, Expense, Supplier
        from branches.models import Branch

        return {
            'users':     PharmUser.objects.filter(organization=org).count(),
            'items':     Item.objects.filter(organization=org).count(),
            'customers': Customer.objects.filter(organization=org).count(),
            'sales':     Sale.objects.filter(organization=org).count(),
            'expenses':  Expense.objects.filter(organization=org).count(),
            'suppliers': Supplier.objects.filter(organization=org).count(),
            'branches':  Branch.objects.filter(organization=org).count(),
        }

    def delete_model(self, request, obj):
        """
        Custom delete: deactivate orphaned users and log the event,
        then delete the org (CASCADE handles all related data).
        """
        from .models import ActivityLog

        org_name = str(obj)
        impact = self._org_impact(obj)

        with transaction.atomic():
            # Deactivate users before SET_NULL leaves them orphaned
            deactivated = PharmUser.objects.filter(organization=obj).update(
                is_active=False, is_staff=False
            )

            # Log before delete (FK goes to NULL after, so capture now)
            ActivityLog.objects.create(
                organization=None,
                user=request.user,
                username=request.user.get_full_name() or request.user.phone_number,
                role=request.user.role,
                action='delete_organization',
                category='settings',
                description=(
                    f"Superuser deleted org '{org_name}'. "
                    f"Impact: {impact['users']} users deactivated, "
                    f"{impact['items']} items, {impact['customers']} customers, "
                    f"{impact['sales']} sales, {impact['branches']} branches deleted."
                ),
            )

            obj.delete()

        self.message_user(
            request,
            (
                f"Organisation '{org_name}' permanently deleted. "
                f"{deactivated} user(s) deactivated — their JWT tokens will return 401 "
                f"on the next API call, immediately logging them out of the app. "
                f"Cascaded: {impact['items']} items, {impact['customers']} customers, "
                f"{impact['sales']} sales, {impact['branches']} branches."
            ),
            messages.SUCCESS,
        )

    def delete_queryset(self, request, queryset):
        """Bulk delete — apply same deactivation + logging logic per org."""
        for org in queryset:
            self.delete_model(request, org)


# ── PharmUser ─────────────────────────────────────────────────────────────────

class UserPermissionOverrideInline(admin.TabularInline):
    model = UserPermissionOverride
    extra = 0
    fields = ('permission', 'granted', 'note', 'created_at')
    readonly_fields = ('created_at',)
    verbose_name = 'Permission Override'
    verbose_name_plural = 'Individual Permission Overrides'

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')


class _PhoneCleanMixin:
    """
    Validates phone_number in admin forms: normalizes to canonical
    0XXXXXXXXXX and rejects duplicates across stored +234... / 234... / 0...
    variants.
    """
    def clean_phone_number(self):
        raw = (self.cleaned_data.get('phone_number') or '').strip()
        # Unchanged (possibly legacy-format) numbers pass through untouched.
        if self.instance.pk and raw == self.instance.phone_number:
            return raw
        phone = normalize_ng_phone(raw)
        if phone is None:
            raise forms.ValidationError(
                'Enter a valid Nigerian mobile number (e.g. 08012345678).')
        variants = [phone, '+234' + phone[1:], '234' + phone[1:]]
        if PharmUser.objects.filter(phone_number__in=variants).exclude(pk=self.instance.pk).exists():
            raise forms.ValidationError('A user with this phone number already exists.')
        return phone


class PharmUserAdminForm(_PhoneCleanMixin, UserChangeForm):
    class Meta(UserChangeForm.Meta):
        model = PharmUser
        fields = '__all__'


class PharmUserAddForm(_PhoneCleanMixin, UserCreationForm):
    class Meta(UserCreationForm.Meta):
        model = PharmUser
        fields = ('phone_number',)


@admin.register(PharmUser)
class PharmUserAdmin(OrgScopedAdminMixin, UserAdmin):
    """
    Org-scoped user admin.
    • Superusers see all users across all organisations.
    • Org staff see only users that belong to their own organisation.
    • Org staff cannot grant is_superuser, Admin role, or change the organisation FK.
    """

    change_form_template = 'admin/authapp/pharmuser/change_form.html'

    form = PharmUserAdminForm
    add_form = PharmUserAddForm
    inlines = [UserPermissionOverrideInline]

    list_display = [
        "phone_number", "full_name", "role_badge", "organization", "branch",
        "is_active", "is_staff", "is_wholesale_operator",
    ]
    list_filter  = ["role", "is_active", "is_staff", "is_wholesale_operator", "branch"]
    search_fields = ["phone_number", "full_name"]
    ordering = ["phone_number"]
    list_select_related = ["organization", "branch"]

    # Superuser fieldsets (full control)
    _superuser_fieldsets = (
        ('Identity', {"fields": ("phone_number", "full_name", "password")}),
        ("Role & Access", {
            "fields": ("role_access_panel", "role", "organization", "branch", "is_wholesale_operator"),
        }),
        ("Django Permissions", {
            "classes": ("collapse",),
            "fields": (
                "is_active", "is_staff", "is_superuser",
                "groups", "user_permissions",
            ),
        }),
    )

    # Org-admin fieldsets (restricted — no superuser, no org reassignment)
    _org_fieldsets = (
        ('Identity', {"fields": ("phone_number", "full_name", "password")}),
        ("Role & Access", {
            "fields": ("role_access_panel", "role", "branch", "is_wholesale_operator"),
        }),
        ("Account", {
            "fields": ("is_active", "is_staff"),
        }),
    )

    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("phone_number", "full_name", "role", "password1", "password2"),
        }),
    )

    readonly_fields = ["role_access_panel"]

    # ── Dynamic fieldsets ─────────────────────────────────────────────────

    def get_fieldsets(self, request, obj=None):
        if obj is None:
            return self.add_fieldsets
        if request.user.is_superuser:
            return self._superuser_fieldsets
        return self._org_fieldsets

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "organization" not in filters:
            filters.insert(0, "organization")
        return filters

    def get_readonly_fields(self, request, obj=None):
        rof = list(self.readonly_fields)
        if not request.user.is_superuser:
            rof.append("organization")
            # Phone number is the login credential — only superusers may change it.
            if obj is not None:
                rof.append("phone_number")
        return rof

    # ── Role restrictions ─────────────────────────────────────────────────

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == 'branch' and not request.user.is_superuser:
            org = getattr(request.user, 'organization', None)
            if org:
                from branches.models import Branch
                kwargs['queryset'] = Branch.objects.filter(organization=org, is_active=True)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

    def formfield_for_choice_field(self, db_field, request, **kwargs):
        """Org admins cannot assign the Admin role — only superusers can."""
        field = super().formfield_for_choice_field(db_field, request, **kwargs)
        if db_field.name == 'role' and not request.user.is_superuser:
            field.choices = [
                (v, l) for v, l in field.choices if v != 'Admin'
            ]
        return field

    # ── Prevent privilege escalation ──────────────────────────────────────

    def save_model(self, request, obj, form, change):
        if not request.user.is_superuser:
            obj.is_superuser = False
            if obj.role == 'Admin':
                obj.role = 'Manager'            # silently cap at Manager
            org = getattr(request.user, "organization", None)
            if org:
                obj.organization = org
        # Auto-sync is_wholesale_operator with role
        obj.is_wholesale_operator = obj.role in _WHOLESALE_ROLES
        super().save_model(request, obj, form, change)

    # ── Quick role assignment + permission overrides ──────────────────────

    def change_view(self, request, object_id, form_url='', extra_context=None):
        from django.http import HttpResponseRedirect
        from .models import ROLE_CHOICES, ALL_PERMISSIONS

        obj = self.get_object(request, object_id)

        # Custom POST handlers below run BEFORE super().change_view()'s
        # permission check — enforce change permission here or a view-only
        # staff user could mutate roles/overrides.
        _can_change = obj is not None and self.has_change_permission(request, obj)
        if (
            request.method == 'POST'
            and ('_quick_role' in request.POST or '_save_permissions' in request.POST)
            and not _can_change
        ):
            self.message_user(request, "You don't have permission to change this user.", messages.ERROR)
            return HttpResponseRedirect(request.path)

        # ── Quick role button ─────────────────────────────────────────────
        if request.method == 'POST' and '_quick_role' in request.POST and obj:
            new_role = request.POST['_quick_role']
            valid_roles = {v for v, _ in ROLE_CHOICES}
            if new_role in valid_roles:
                if new_role == 'Admin' and not request.user.is_superuser:
                    self.message_user(request, "Only superusers can grant the Admin role.", messages.ERROR)
                else:
                    obj.role = new_role
                    obj.is_wholesale_operator = new_role in _WHOLESALE_ROLES
                    obj.save(update_fields=['role', 'is_wholesale_operator'])
                    self.message_user(
                        request,
                        f"Role updated to '{new_role}'. is_wholesale_operator synced automatically.",
                        messages.SUCCESS,
                    )
            return HttpResponseRedirect(request.path)

        # ── Save permission overrides ────────────────────────────────────
        if request.method == 'POST' and '_save_permissions' in request.POST and obj:
            saved = revoked = cleared = 0
            for perm in ALL_PERMISSIONS:
                val = request.POST.get(f'perm_{perm}', 'inherit')
                if val == 'grant':
                    _, created = UserPermissionOverride.objects.update_or_create(
                        user=obj, permission=perm,
                        defaults={'granted': True},
                    )
                    saved += 1
                elif val == 'revoke':
                    _, created = UserPermissionOverride.objects.update_or_create(
                        user=obj, permission=perm,
                        defaults={'granted': False},
                    )
                    revoked += 1
                else:  # inherit — remove any override
                    deleted, _ = UserPermissionOverride.objects.filter(user=obj, permission=perm).delete()
                    cleared += deleted
            self.message_user(
                request,
                f"Permission overrides saved: {saved} granted, {revoked} revoked, {cleared} cleared.",
                messages.SUCCESS,
            )
            return HttpResponseRedirect(request.path)

        # ── Build template context ────────────────────────────────────────
        extra_context = extra_context or {}
        if obj:
            override_map = {
                ov.permission: ov.granted
                for ov in UserPermissionOverride.objects.filter(user=obj)
            }
            perm_rows = []
            for label, allowed in _PERM_MATRIX:
                perm_key     = _PERM_LABEL_TO_KEY.get(label)
                role_default = obj.role in allowed
                override_val = override_map.get(perm_key)   # None / True / False
                effective    = role_default if override_val is None else override_val
                state = 'inherit' if override_val is None else ('grant' if override_val else 'revoke')
                perm_rows.append({
                    'label':        label,
                    'key':          perm_key,
                    'role_default': role_default,
                    'state':        state,   # 'inherit' | 'grant' | 'revoke'
                    'effective':    effective,
                })

            extra_context.update({
                'role_colors':     ROLE_COLORS,
                'current_role':    obj.role,
                'can_set_admin':   request.user.is_superuser,
                'all_roles':       ROLE_CHOICES,
                'perm_rows':       perm_rows,
                'n_overrides':     len(override_map),
            })
        return super().change_view(request, object_id, form_url, extra_context)

    # ── Display helpers ───────────────────────────────────────────────────

    @admin.display(description="Role")
    def role_badge(self, obj):
        color = ROLE_COLORS.get(obj.role, '#6B7280')
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 10px;'
            'border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, obj.role,
        )

    @admin.display(description="Role & Permissions")
    def role_access_panel(self, obj):
        if not obj or not obj.pk:
            return mark_safe('<p style="color:#64748b;font-size:12px">Save the user first to see the permission panel.</p>')

        role   = obj.role
        color  = ROLE_COLORS.get(role, '#6B7280')
        role   = conditional_escape(role)

        # Fetch overrides for this user
        override_map = {
            ov.permission: ov.granted
            for ov in UserPermissionOverride.objects.filter(user=obj)
        }

        rows_html = ''
        for label, allowed in _PERM_MATRIX:
            perm_key     = _PERM_LABEL_TO_KEY.get(label)
            role_default = role in allowed
            override_val = override_map.get(perm_key)  # None if no override

            effective = role_default if override_val is None else override_val

            if override_val is True:
                override_cell = '<span style="color:#10b981;font-size:11px;font-weight:600">Grant ↑</span>'
            elif override_val is False:
                override_cell = '<span style="color:#ef4444;font-size:11px;font-weight:600">Revoke ↓</span>'
            else:
                override_cell = '<span style="color:#475569;font-size:11px">—</span>'

            def_icon  = '✅' if role_default else '❌'
            eff_icon  = '✅' if effective else '❌'
            def_style = 'color:#94a3b8' if role_default else 'color:#475569'
            eff_style = 'color:#10b981;font-weight:600' if effective else 'color:#475569'

            rows_html += (
                f'<tr style="border-bottom:1px solid var(--border-color,#dee2e6)">'
                f'<td style="padding:5px 10px;font-size:12px;color:var(--body-quiet-color,#555);opacity:0.85">{label}</td>'
                f'<td style="padding:5px 10px;text-align:center;font-size:13px;{def_style}">{def_icon}</td>'
                f'<td style="padding:5px 10px;text-align:center">{override_cell}</td>'
                f'<td style="padding:5px 10px;text-align:center;font-size:13px;{eff_style}">{eff_icon}</td>'
                f'</tr>'
            )

        ws_flag  = '✅ Yes' if obj.is_wholesale_operator else '❌ No'
        ws_color = '#10b981' if obj.is_wholesale_operator else '#64748b'
        n_overrides = len(override_map)
        override_note = (
            f'<span style="background:rgba(239,68,68,0.1);color:#ef4444;border:1px solid rgba(239,68,68,0.3);'
            f'border-radius:6px;padding:2px 8px;font-size:10px;font-weight:600">'
            f'{n_overrides} override{"s" if n_overrides != 1 else ""} active</span>'
        ) if n_overrides else ''

        html = f'''
<div style="margin:4px 0 8px;font-family:inherit">
  <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;flex-wrap:wrap">
    <span style="background:{color};color:#fff;padding:5px 18px;border-radius:20px;
                 font-size:13px;font-weight:700;letter-spacing:0.03em">{role}</span>
    <span style="font-size:11px;color:var(--body-quiet-color,#666);background:var(--darkened-bg,rgba(0,0,0,0.04));
                 padding:4px 10px;border-radius:6px;border:1px solid var(--border-color,#dee2e6)">
      Wholesale Operator: <strong style="color:{ws_color}">{ws_flag}</strong>
    </span>
    {override_note}
  </div>
  <table style="width:100%;max-width:540px;border-collapse:collapse;
                background:var(--darkened-bg,rgba(0,0,0,0.02));border-radius:8px;overflow:hidden;
                border:1px solid var(--border-color,#dee2e6)">
    <thead>
      <tr style="background:var(--darkened-bg,rgba(0,0,0,0.06))">
        <th style="padding:6px 10px;text-align:left;font-size:10px;color:var(--body-quiet-color,#666);letter-spacing:0.08em;text-transform:uppercase">Module</th>
        <th style="padding:6px 10px;text-align:center;font-size:10px;color:var(--body-quiet-color,#666);letter-spacing:0.08em;text-transform:uppercase">Role Default</th>
        <th style="padding:6px 10px;text-align:center;font-size:10px;color:var(--body-quiet-color,#666);letter-spacing:0.08em;text-transform:uppercase">Override</th>
        <th style="padding:6px 10px;text-align:center;font-size:10px;color:var(--body-quiet-color,#666);letter-spacing:0.08em;text-transform:uppercase">Effective</th>
      </tr>
    </thead>
    <tbody>{rows_html}</tbody>
  </table>
  <p style="margin-top:8px;font-size:10.5px;color:var(--body-quiet-color,#666)">
    Add overrides in the <em>Individual Permission Overrides</em> section below.
    Changes take effect on next login.
  </p>
</div>'''
        return mark_safe(html)

    @admin.display(description="Status")
    def status_badge(self, obj):
        color = "#28a745" if obj.is_active else "#dc3545"
        label = "Active" if obj.is_active else "Inactive"
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:4px;font-size:11px">{}</span>',
            color, label,
        )


# ── SiteConfig ────────────────────────────────────────────────────────────────

@admin.register(SiteConfig)
class SiteConfigAdmin(admin.ModelAdmin):
    """Global system config — superusers only."""

    changelist_template = "admin/authapp/siteconfig/changelist.html"

    # ── Superuser-only permissions ─────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser and not SiteConfig.objects.exists()

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return False

    # ── Changelist with environment / maintenance controls ─────────────────

    def changelist_view(self, request, extra_context=None):
        cfg = SiteConfig.get_solo()

        # super().changelist_view() checks permission AFTER this code runs —
        # enforce here so a non-superuser POST can't flip env/maintenance first.
        if request.method == "POST" and request.user.is_superuser:
            action = request.POST.get("env_action")
            if action in ("dev", "prod"):
                cfg.active_environment = action
                cfg.save()
                label = "Development" if action == "dev" else "Production"
                level = messages.SUCCESS if action == "dev" else messages.WARNING
                self.message_user(
                    request,
                    f"Environment set to {label}. Restart the server to apply.",
                    level=level,
                )

            maint = request.POST.get("maintenance_mode")
            if maint is not None:
                cfg.maintenance_mode = maint == "1"
                cfg.save()
                state = "enabled" if cfg.maintenance_mode else "disabled"
                self.message_user(request, f"Maintenance mode {state}.")

        extra_context = extra_context or {}
        extra_context.update(
            {
                "cfg":            cfg,
                "running_env":    SiteConfig.running_env(),
                "pending_env":    SiteConfig.pending_env(),
                "running_module": SiteConfig.running_module(),
                "pending_module": SiteConfig.pending_module(),
                "restart_needed": SiteConfig.restart_needed(),
            }
        )
        return super().changelist_view(request, extra_context=extra_context)


# ── Activity Log ──────────────────────────────────────────────────────────────

@admin.register(ActivityLog)
class ActivityLogAdmin(admin.ModelAdmin):
    """Read-only audit trail for all significant actions."""

    list_display  = ["timestamp", "username", "role_badge", "action", "category_badge",
                     "organization", "ip_address"]
    list_filter   = ["category", "role", "timestamp"]
    search_fields = ["username", "action", "description", "ip_address"]
    ordering      = ["-timestamp"]
    date_hierarchy = "timestamp"
    list_select_related = ["organization"]
    readonly_fields = [
        "organization", "user", "username", "role", "action",
        "category", "description", "ip_address", "timestamp",
    ]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(organization=org) if org else qs.none()

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "organization" not in filters:
            filters.insert(0, "organization")
        return filters

    @admin.display(description="Role")
    def role_badge(self, obj):
        color = ROLE_COLORS.get(obj.role, "#6B7280")
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;'
            'border-radius:10px;font-size:11px">{}</span>',
            color, obj.role or "—",
        )

    @admin.display(description="Category")
    def category_badge(self, obj):
        colors = {
            "auth": "#3B82F6", "sales": "#10B981", "inventory": "#8B5CF6",
            "customers": "#06B6D4", "users": "#F59E0B", "settings": "#EF4444",
            "reports": "#6366F1", "other": "#6B7280",
        }
        c = colors.get(obj.category, "#6B7280")
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;'
            'border-radius:10px;font-size:11px">{}</span>',
            c, obj.get_category_display(),
        )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


# ── Pharmacy Network ──────────────────────────────────────────────────────────

class PharmacyNetworkMembershipInline(admin.TabularInline):
    model  = PharmacyNetworkMembership
    extra  = 0
    fields = ("organization", "role", "status", "invited_by", "joined_at")
    readonly_fields = ("joined_at",)
    show_change_link = True


@admin.register(PharmacyNetwork)
class PharmacyNetworkAdmin(admin.ModelAdmin):
    """Superuser-only — cross-org network management."""

    list_display   = ["name", "slug", "created_by", "member_count", "is_active", "is_default", "created_at"]
    list_filter    = ["is_active", "is_default"]
    search_fields  = ["name", "slug", "created_by__name"]
    readonly_fields = ["slug", "created_at"]
    ordering       = ["name"]
    inlines        = [PharmacyNetworkMembershipInline]
    list_select_related = ["created_by"]

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(
            _member_count=Count("memberships", filter=Q(memberships__status="active"))
        )

    @admin.display(description="Members", ordering="_member_count")
    def member_count(self, obj):
        return obj._member_count

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


@admin.register(PharmacyNetworkMembership)
class PharmacyNetworkMembershipAdmin(admin.ModelAdmin):
    """Superuser-only — manage individual network memberships."""

    list_display  = ["organization", "network", "role", "status", "invited_by", "joined_at", "created_at"]
    list_filter   = ["status", "role", "created_at"]
    search_fields = ["organization__name", "network__name"]
    readonly_fields = ["created_at"]
    ordering      = ["-created_at"]
    list_select_related = ["organization", "network", "invited_by"]

    actions = ["approve_memberships", "suspend_memberships"]

    @admin.action(description="Approve selected pending memberships")
    def approve_memberships(self, request, queryset):
        from django.utils.timezone import now as tz_now
        updated = queryset.filter(status="pending").update(status="active", joined_at=tz_now())
        self.message_user(request, f"{updated} membership(s) approved.")

    @admin.action(description="Suspend selected active memberships")
    def suspend_memberships(self, request, queryset):
        updated = queryset.filter(status="active").update(status="suspended")
        self.message_user(request, f"{updated} membership(s) suspended.")

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


# ── Commission Config ─────────────────────────────────────────────────────────

@admin.register(CommissionConfig)
class CommissionConfigAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    """Per-user commission rates — org-scoped."""

    list_display  = ["user", "organization", "commission_rate_pct", "fixed_bonus", "is_active", "updated_at"]
    list_filter   = ["is_active"]
    search_fields = ["user__phone_number", "user__full_name", "organization__name"]
    ordering      = ["user__full_name"]
    readonly_fields = ["updated_at"]
    list_select_related = ["user", "organization"]

    fieldsets = (
        (None, {"fields": ("user", "commission_rate", "fixed_bonus", "is_active")}),
        ("Meta", {"fields": ("updated_at",), "classes": ("collapse",)}),
    )

    @admin.display(description="Rate")
    def commission_rate_pct(self, obj):
        return f"{obj.commission_rate * 100:.1f}%"

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "user" and not request.user.is_superuser:
            org = getattr(request.user, "organization", None)
            if org:
                kwargs["queryset"] = PharmUser.objects.filter(organization=org)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


# ── Admin site branding ───────────────────────────────────────────────────────

admin.site.site_header = "PharmApp Administration"
admin.site.site_title  = "PharmApp Admin"
admin.site.index_title = "Pharmacy Management System"
