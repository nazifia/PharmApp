from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html

from .models import Organization, PharmUser, SiteConfig


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "phone", "created_at"]
    search_fields = ["name", "slug", "phone"]
    readonly_fields = ["slug", "created_at"]
    ordering = ["name"]


@admin.register(PharmUser)
class PharmUserAdmin(UserAdmin):
    list_display = [
        "phone_number", "role", "organization", "is_active", "is_staff",
        "is_superuser", "is_wholesale_operator",
    ]
    list_filter = ["role", "organization", "is_active", "is_staff", "is_superuser", "is_wholesale_operator"]
    search_fields = ["phone_number"]
    ordering = ["phone_number"]

    fieldsets = (
        (None, {"fields": ("phone_number", "password")}),
        ("Role & Access", {
            "fields": ("role", "organization", "is_wholesale_operator"),
        }),
        ("Permissions", {
            "classes": ("collapse",),
            "fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions"),
        }),
    )

    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("phone_number", "role", "password1", "password2"),
        }),
    )

    # UserAdmin uses username; override to phone_number
    readonly_fields = []

    def status_badge(self, obj):
        color = "#28a745" if obj.is_active else "#dc3545"
        label = "Active" if obj.is_active else "Inactive"
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;border-radius:4px;font-size:11px">{}</span>',
            color, label
        )
    status_badge.short_description = "Status"


@admin.register(SiteConfig)
class SiteConfigAdmin(admin.ModelAdmin):
    changelist_template = 'admin/authapp/siteconfig/changelist.html'

    def has_add_permission(self, request):
        return not SiteConfig.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False

    def changelist_view(self, request, extra_context=None):
        cfg = SiteConfig.get_solo()

        if request.method == 'POST':
            action = request.POST.get('env_action')
            if action in ('dev', 'prod'):
                cfg.active_environment = action
                cfg.save()
                label = 'Development' if action == 'dev' else 'Production'
                level  = messages.SUCCESS if action == 'dev' else messages.WARNING
                self.message_user(
                    request,
                    f'Environment set to {label}. Restart the server to apply.',
                    level=level,
                )

            maint = request.POST.get('maintenance_mode')
            if maint is not None:
                cfg.maintenance_mode = (maint == '1')
                cfg.save()
                state = 'enabled' if cfg.maintenance_mode else 'disabled'
                self.message_user(request, f'Maintenance mode {state}.')

        extra_context = extra_context or {}
        extra_context.update({
            'cfg':             cfg,
            'running_env':     SiteConfig.running_env(),
            'pending_env':     SiteConfig.pending_env(),
            'running_module':  SiteConfig.running_module(),
            'pending_module':  SiteConfig.pending_module(),
            'restart_needed':  SiteConfig.restart_needed(),
        })
        return super().changelist_view(request, extra_context=extra_context)


# Customise admin site branding
admin.site.site_header = "PharmApp Administration"
admin.site.site_title = "PharmApp Admin"
admin.site.index_title = "Pharmacy Management System"
