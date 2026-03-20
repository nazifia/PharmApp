from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html

from .models import PharmUser


@admin.register(PharmUser)
class PharmUserAdmin(UserAdmin):
    list_display = [
        "phone_number", "role", "is_active", "is_staff",
        "is_superuser", "is_wholesale_operator",
    ]
    list_filter = ["role", "is_active", "is_staff", "is_superuser", "is_wholesale_operator"]
    search_fields = ["phone_number"]
    ordering = ["phone_number"]

    fieldsets = (
        (None, {"fields": ("phone_number", "password")}),
        ("Role & Access", {
            "fields": ("role", "is_wholesale_operator"),
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


# Customise admin site branding
admin.site.site_header = "PharmApp Administration"
admin.site.site_title = "PharmApp Admin"
admin.site.index_title = "Pharmacy Management System"
