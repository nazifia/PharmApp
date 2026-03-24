from django.contrib import admin
from django.utils.html import format_html

from authapp.admin_mixins import OrgScopedAdminMixin
from .models import Customer, WalletTransaction


class WalletTransactionInline(admin.TabularInline):
    model = WalletTransaction
    extra = 0
    readonly_fields = ["txn_type", "amount", "note", "created"]
    can_delete = False
    ordering = ["-created"]
    max_num = 0  # read-only inline

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Customer)
class CustomerAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display = [
        "name", "phone", "email", "customer_type_badge",
        "wallet_balance", "outstanding_debt", "total_purchases_display",
        "join_date", "last_visit",
    ]
    list_filter  = ["is_wholesale", "join_date"]
    search_fields = ["name", "phone", "email"]
    ordering = ["name"]
    readonly_fields = ["total_purchases_display", "join_date"]
    inlines = [WalletTransactionInline]

    fieldsets = (
        ("Basic Information", {
            "fields": ("name", "phone", "email", "address"),
        }),
        ("Account", {
            "fields": ("is_wholesale", "wallet_balance", "outstanding_debt"),
        }),
        ("Activity", {
            "fields": ("join_date", "last_visit", "total_purchases_display"),
        }),
    )

    @admin.display(description="Type")
    def customer_type_badge(self, obj):
        if obj.is_wholesale:
            return format_html(
                '<span style="background:#6f42c1;color:white;padding:2px 8px;'
                'border-radius:4px;font-size:11px">Wholesale</span>'
            )
        return format_html(
            '<span style="background:#0d6efd;color:white;padding:2px 8px;'
            'border-radius:4px;font-size:11px">Retail</span>'
        )

    @admin.display(description="Total Purchases")
    def total_purchases_display(self, obj):
        try:
            return f"₦{obj.total_purchases():,.2f}"
        except Exception:
            return "—"

    actions = ["mark_as_wholesale", "mark_as_retail", "reset_wallet_balance"]

    @admin.action(description="Mark selected customers as Wholesale")
    def mark_as_wholesale(self, request, queryset):
        updated = queryset.update(is_wholesale=True)
        self.message_user(request, f"{updated} customer(s) marked as wholesale.")

    @admin.action(description="Mark selected customers as Retail")
    def mark_as_retail(self, request, queryset):
        updated = queryset.update(is_wholesale=False)
        self.message_user(request, f"{updated} customer(s) marked as retail.")

    @admin.action(description="Reset wallet balance to zero")
    def reset_wallet_balance(self, request, queryset):
        updated = queryset.update(wallet_balance=0)
        self.message_user(request, f"Wallet balance reset for {updated} customer(s).")


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display  = ["customer", "txn_type_badge", "amount", "note", "created"]
    list_filter   = ["txn_type", "created"]
    search_fields = ["customer__name", "customer__phone", "note"]
    ordering      = ["-created"]
    readonly_fields = ["customer", "txn_type", "amount", "note", "created"]
    date_hierarchy = "created"

    def get_queryset(self, request):
        """Scope to current org via customer → organisation traversal."""
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        if org is None:
            return qs.none()
        return qs.filter(customer__organization=org)

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "customer__organization" not in filters:
            filters.insert(0, "customer__organization")
        return filters

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    @admin.display(description="Type")
    def txn_type_badge(self, obj):
        colors = {"topup": "#28a745", "deduct": "#dc3545", "purchase": "#fd7e14"}
        color = colors.get(obj.txn_type, "#6c757d")
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:4px;font-size:11px">{}</span>',
            color, obj.txn_type.title(),
        )
