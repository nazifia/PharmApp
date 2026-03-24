from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html

from .admin_mixins import OrgScopedAdminMixin
from .models import Organization, PharmUser, SiteConfig


# ── Organisation ──────────────────────────────────────────────────────────────

@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    """Visible and editable by superusers only."""

    list_display  = ["name", "slug", "phone", "user_count", "created_at"]
    search_fields = ["name", "slug", "phone"]
    readonly_fields = ["slug", "created_at", "user_count"]
    ordering = ["name"]

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

@admin.register(PharmUser)
class PharmUserAdmin(OrgScopedAdminMixin, UserAdmin):
    """
    Org-scoped user admin.
    • Superusers see all users across all organisations.
    • Org staff see only users that belong to their own organisation.
    • Org staff cannot grant is_superuser or change the organisation FK.
    """

    list_display = [
        "phone_number", "full_name", "role", "organization", "is_active",
        "is_staff", "is_wholesale_operator",
    ]
    list_filter  = ["role", "is_active", "is_staff", "is_wholesale_operator"]
    search_fields = ["phone_number", "full_name"]
    ordering = ["phone_number"]

    # Superuser fieldsets (full control)
    _superuser_fieldsets = (
        (None, {"fields": ("phone_number", "full_name", "password")}),
        ("Role & Access", {
            "fields": ("role", "organization", "is_wholesale_operator"),
        }),
        ("Permissions", {
            "classes": ("collapse",),
            "fields": (
                "is_active", "is_staff", "is_superuser",
                "groups", "user_permissions",
            ),
        }),
    )

    # Org-admin fieldsets (restricted — no superuser, no org reassignment)
    _org_fieldsets = (
        (None, {"fields": ("phone_number", "full_name", "password")}),
        ("Role & Access", {
            "fields": ("role", "is_wholesale_operator"),
        }),
        ("Permissions", {
            "classes": ("collapse",),
            "fields": ("is_active", "is_staff"),
        }),
    )

    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("phone_number", "full_name", "role", "password1", "password2"),
        }),
    )

    # UserAdmin uses username; override to phone_number
    readonly_fields = []

    # ── Dynamic fieldsets based on requester role ──────────────────────────

    def get_fieldsets(self, request, obj=None):
        if request.user.is_superuser:
            return self._superuser_fieldsets
        return self._org_fieldsets

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "organization" not in filters:
            filters.insert(0, "organization")
        return filters

    def get_readonly_fields(self, request, obj=None):
        rof = list(super().get_readonly_fields(request, obj))
        if not request.user.is_superuser:
            # Org admins cannot move users to another org
            if "organization" not in rof:
                rof.append("organization")
        return rof

    # ── Prevent privilege escalation ──────────────────────────────────────

    def save_model(self, request, obj, form, change):
        if not request.user.is_superuser:
            obj.is_superuser = False            # cannot escalate to superuser
            org = getattr(request.user, "organization", None)
            if org:
                obj.organization = org          # always assign to own org
        super().save_model(request, obj, form, change)

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
