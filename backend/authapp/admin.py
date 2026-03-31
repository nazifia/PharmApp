from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin
from django.utils.html import conditional_escape, format_html, mark_safe
from django.urls import reverse

from .admin_mixins import OrgScopedAdminMixin
from .models import Organization, PharmUser, SiteConfig, UserPermissionOverride

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

    list_display  = ["name", "slug", "phone", "user_count", "subscription_plan", "created_at"]
    search_fields = ["name", "slug", "phone"]
    readonly_fields = ["slug", "created_at", "user_count"]
    ordering = ["name"]
    inlines  = []   # populated in get_inlines()

    def get_inlines(self, request, obj):
        return _subscription_inline()

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

    @admin.display(description="Users")
    def user_count(self, obj):
        return obj.users.count()

    # ── Superuser-only permissions ─────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


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


@admin.register(PharmUser)
class PharmUserAdmin(OrgScopedAdminMixin, UserAdmin):
    """
    Org-scoped user admin.
    • Superusers see all users across all organisations.
    • Org staff see only users that belong to their own organisation.
    • Org staff cannot grant is_superuser, Admin role, or change the organisation FK.
    """

    change_form_template = 'admin/authapp/pharmuser/change_form.html'

    inlines = [UserPermissionOverrideInline]

    list_display = [
        "phone_number", "full_name", "role_badge", "organization", "is_active",
        "is_staff", "is_wholesale_operator",
    ]
    list_filter  = ["role", "is_active", "is_staff", "is_wholesale_operator"]
    search_fields = ["phone_number", "full_name"]
    ordering = ["phone_number"]

    # Superuser fieldsets (full control)
    _superuser_fieldsets = (
        ('Identity', {"fields": ("phone_number", "full_name", "password")}),
        ("Role & Access", {
            "fields": ("role_access_panel", "role", "organization", "is_wholesale_operator"),
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
            "fields": ("role_access_panel", "role", "is_wholesale_operator"),
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
        return rof

    # ── Role restrictions ─────────────────────────────────────────────────

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
                f'<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">'
                f'<td style="padding:5px 10px;font-size:12px;color:#94a3b8">{label}</td>'
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
    <span style="font-size:11px;color:#64748b;background:rgba(255,255,255,0.04);
                 padding:4px 10px;border-radius:6px;border:1px solid rgba(255,255,255,0.08)">
      Wholesale Operator: <strong style="color:{ws_color}">{ws_flag}</strong>
    </span>
    {override_note}
  </div>
  <table style="width:100%;max-width:540px;border-collapse:collapse;
                background:rgba(255,255,255,0.03);border-radius:8px;overflow:hidden;
                border:1px solid rgba(255,255,255,0.08)">
    <thead>
      <tr style="background:rgba(255,255,255,0.06)">
        <th style="padding:6px 10px;text-align:left;font-size:10px;color:#64748b;letter-spacing:0.08em;text-transform:uppercase">Module</th>
        <th style="padding:6px 10px;text-align:center;font-size:10px;color:#64748b;letter-spacing:0.08em;text-transform:uppercase">Role Default</th>
        <th style="padding:6px 10px;text-align:center;font-size:10px;color:#64748b;letter-spacing:0.08em;text-transform:uppercase">Override</th>
        <th style="padding:6px 10px;text-align:center;font-size:10px;color:#64748b;letter-spacing:0.08em;text-transform:uppercase">Effective</th>
      </tr>
    </thead>
    <tbody>{rows_html}</tbody>
  </table>
  <p style="margin-top:8px;font-size:10.5px;color:#475569">
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

        if request.method == "POST":
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


# ── Admin site branding ───────────────────────────────────────────────────────

admin.site.site_header = "PharmApp Administration"
admin.site.site_title  = "PharmApp Admin"
admin.site.index_title = "Pharmacy Management System"
