from django.contrib import admin
from django.utils.html import format_html
from django.utils.timezone import now

from authapp.admin_mixins import OrgScopedAdminMixin
from .models import (
    Cashier,
    Sale,
    SaleItem,
    DispensingLog,
    PaymentRequest,
    PaymentRequestItem,
    ReceiptPayment,
    ReturnRecord,
    ExpenseCategory,
    Expense,
    Supplier,
    Procurement,
    ProcurementItem,
    StockCheck,
    StockCheckItem,
    Notification,
    TransferRequest,
)


# ── Shared helpers ─────────────────────────────────────────────────────────────

def _badge(label, color):
    return format_html(
        '<span style="background:{};color:white;padding:2px 8px;'
        'border-radius:4px;font-size:11px">{}</span>',
        color, label,
    )


STATUS_COLORS = {
    "pending":            "#ffc107",
    "completed":          "#28a745",
    "returned":           "#dc3545",
    "partial_return":     "#fd7e14",
    "partially_returned": "#fd7e14",
    "accepted":           "#0d6efd",
    "rejected":           "#dc3545",
    "cancelled":          "#6c757d",
    "draft":              "#6c757d",
    "in_progress":        "#0d6efd",
    "approved":           "#28a745",
    "adjusted":           "#17a2b8",
    "received":           "#28a745",
    "low":                "#6c757d",
    "medium":             "#0d6efd",
    "high":               "#fd7e14",
    "critical":           "#dc3545",
}


def status_badge(status):
    color = STATUS_COLORS.get(status.lower(), "#6c757d")
    return _badge(status.replace("_", " ").title(), color)


# ── Cashier ────────────────────────────────────────────────────────────────────

@admin.register(Cashier)
class CashierAdmin(admin.ModelAdmin):
    list_display  = ["cashier_id", "name", "user", "cashier_type", "is_active", "created_at"]
    list_filter   = ["cashier_type", "is_active"]
    search_fields = ["name", "cashier_id", "user__phone_number"]
    ordering      = ["name"]
    readonly_fields = ["cashier_id", "created_at"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        if org is None:
            return qs.none()
        return qs.filter(user__organization=org)

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "user__organization" not in filters:
            filters.insert(0, "user__organization")
        return filters

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        org = None if request.user.is_superuser else getattr(request.user, "organization", None)
        if org and db_field.name == "user":
            from django.contrib.auth import get_user_model
            kwargs["queryset"] = get_user_model().objects.filter(organization=org)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


# ── Sale & SaleItems ───────────────────────────────────────────────────────────

class SaleItemInline(admin.TabularInline):
    model  = SaleItem
    extra  = 0
    readonly_fields = [
        "item", "name", "brand", "dosage_form", "unit",
        "quantity", "price", "discount", "subtotal",
        "barcode", "returned", "return_qty",
    ]
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


class ReceiptPaymentInline(admin.TabularInline):
    model  = ReceiptPayment
    extra  = 0
    readonly_fields = ["payment_method", "amount", "status", "date"]
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Sale)
class SaleAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display = [
        "receipt_id", "customer", "buyer_name", "sale_type_badge",
        "total_amount", "payment_method", "status_display",
        "cashier", "dispenser", "created",
    ]
    list_filter   = ["status", "payment_method", "is_wholesale", "created"]
    search_fields = [
        "receipt_id", "buyer_name", "customer__name",
        "customer__phone", "notes",
    ]
    ordering      = ["-created"]
    readonly_fields = [
        "receipt_id", "created", "total_amount", "discount_total",
        "payment_cash", "payment_pos", "payment_transfer", "payment_wallet",
    ]
    date_hierarchy = "created"
    inlines = [SaleItemInline, ReceiptPaymentInline]

    fieldsets = (
        ("Receipt",  {"fields": ("receipt_id", "status", "created")}),
        ("Customer", {"fields": ("customer", "buyer_name", "buyer_address")}),
        ("Totals",   {"fields": ("total_amount", "discount_total")}),
        ("Payment Breakdown", {
            "fields": (
                "payment_method",
                "payment_cash", "payment_pos",
                "payment_transfer", "payment_wallet",
            ),
        }),
        ("Staff", {"fields": ("cashier", "dispenser", "is_wholesale")}),
        ("Notes", {"fields": ("notes",), "classes": ("collapse",)}),
    )

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)

    @admin.display(description="Type")
    def sale_type_badge(self, obj):
        if obj.is_wholesale:
            return _badge("Wholesale", "#6f42c1")
        return _badge("Retail", "#0d6efd")

    actions = ["mark_completed", "mark_returned"]

    @admin.action(description="Mark selected sales as Completed")
    def mark_completed(self, request, queryset):
        updated = queryset.update(status="completed")
        self.message_user(request, f"{updated} sale(s) marked as completed.")

    @admin.action(description="Mark selected sales as Returned")
    def mark_returned(self, request, queryset):
        updated = queryset.update(status="returned")
        self.message_user(request, f"{updated} sale(s) marked as returned.")


@admin.register(SaleItem)
class SaleItemAdmin(admin.ModelAdmin):
    list_display  = [
        "sale", "name", "brand", "dosage_form",
        "quantity", "price", "discount", "subtotal",
        "returned", "return_qty",
    ]
    list_filter   = ["dosage_form", "returned"]
    search_fields = ["name", "brand", "barcode", "sale__receipt_id"]
    ordering      = ["-sale__created"]
    readonly_fields = ["subtotal", "sale"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(sale__organization=org) if org else qs.none()

    def has_add_permission(self, request):
        return False


# ── Dispensing Log ─────────────────────────────────────────────────────────────

@admin.register(DispensingLog)
class DispensingLogAdmin(admin.ModelAdmin):
    list_display  = [
        "name", "brand", "quantity", "amount",
        "status_display", "user", "sale", "created_at",
    ]
    list_filter   = ["status", "dosage_form", "created_at"]
    search_fields = ["name", "brand", "user__phone_number", "sale__receipt_id"]
    ordering      = ["-created_at"]
    date_hierarchy = "created_at"
    readonly_fields = [
        "user", "sale", "item", "name", "brand",
        "dosage_form", "unit", "quantity", "amount",
        "discount_amount", "status", "created_at",
    ]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(sale__organization=org) if org else qs.none()

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)


# ── Payment Requests ───────────────────────────────────────────────────────────

class PaymentRequestItemInline(admin.TabularInline):
    model  = PaymentRequestItem
    extra  = 0
    readonly_fields = [
        "item", "item_name", "brand", "dosage_form", "unit",
        "quantity", "unit_price", "discount_amount", "subtotal",
    ]
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(PaymentRequest)
class PaymentRequestAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = [
        "request_id", "dispenser", "cashier", "customer",
        "payment_type", "total_amount", "status_display",
        "receipt", "created_at",
    ]
    list_filter   = ["status", "payment_type", "created_at"]
    search_fields = [
        "request_id", "dispenser__phone_number",
        "customer__name", "buyer_name",
    ]
    ordering      = ["-created_at"]
    readonly_fields = ["request_id", "created_at", "updated_at"]
    date_hierarchy  = "created_at"
    inlines = [PaymentRequestItemInline]

    fieldsets = (
        ("Request", {
            "fields": ("request_id", "status", "payment_type", "created_at", "updated_at"),
        }),
        ("Parties", {"fields": ("dispenser", "cashier", "customer", "receipt")}),
        ("Buyer",   {"fields": ("buyer_name", "buyer_address")}),
        ("Amount",  {"fields": ("total_amount",)}),
        ("Notes",   {"fields": ("notes",), "classes": ("collapse",)}),
    )

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)

    actions = ["cancel_requests"]

    @admin.action(description="Cancel selected payment requests")
    def cancel_requests(self, request, queryset):
        updated = queryset.filter(status="pending").update(status="cancelled")
        self.message_user(request, f"{updated} request(s) cancelled.")


@admin.register(ReceiptPayment)
class ReceiptPaymentAdmin(admin.ModelAdmin):
    list_display  = ["receipt", "payment_method", "amount", "status", "date"]
    list_filter   = ["payment_method", "status"]
    search_fields = ["receipt__receipt_id"]
    ordering      = ["-date"]
    readonly_fields = ["receipt", "payment_method", "amount", "status", "date"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(receipt__organization=org) if org else qs.none()

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


# ── Returns ────────────────────────────────────────────────────────────────────

@admin.register(ReturnRecord)
class ReturnRecordAdmin(admin.ModelAdmin):
    list_display  = [
        "sale", "sale_item", "quantity", "amount",
        "refund_method", "reason", "returned_by", "created_at",
    ]
    list_filter   = ["refund_method", "created_at"]
    search_fields = ["sale__receipt_id", "reason", "returned_by__phone_number"]
    ordering      = ["-created_at"]
    date_hierarchy = "created_at"
    readonly_fields = ["sale", "sale_item", "quantity", "amount", "returned_by", "created_at"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(sale__organization=org) if org else qs.none()

    def has_add_permission(self, request):
        return False


# ── Expenses ───────────────────────────────────────────────────────────────────

@admin.register(ExpenseCategory)
class ExpenseCategoryAdmin(admin.ModelAdmin):
    """Shared lookup table — visible to all staff."""
    list_display  = ["name", "expense_count"]
    search_fields = ["name"]
    ordering = ["name"]

    @admin.display(description="# Expenses")
    def expense_count(self, obj):
        return obj.expense_set.count()


@admin.register(Expense)
class ExpenseAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = ["description", "category", "amount", "date", "created_by", "created_at"]
    list_filter   = ["category", "date"]
    search_fields = ["description", "category__name", "created_by__phone_number"]
    ordering      = ["-date"]
    date_hierarchy = "date"
    readonly_fields = ["created_at"]

    fieldsets = (
        (None,  {"fields": ("category", "description", "amount", "date")}),
        ("Meta", {"fields": ("created_by", "created_at")}),
    )


# ── Suppliers & Procurement ────────────────────────────────────────────────────

class ProcurementItemInline(admin.TabularInline):
    model = ProcurementItem
    extra = 0
    readonly_fields = [
        "item_name", "dosage_form", "brand", "unit",
        "quantity", "cost_price", "markup", "subtotal",
        "expiry_date", "barcode",
    ]
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Supplier)
class SupplierAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = ["name", "phone", "procurement_count", "created_at"]
    search_fields = ["name", "phone", "contact_info"]
    ordering      = ["name"]
    readonly_fields = ["created_at"]

    fieldsets = (
        (None, {"fields": ("name", "phone", "contact_info", "created_at")}),
    )

    @admin.display(description="Procurements")
    def procurement_count(self, obj):
        return obj.procurement_set.count()


@admin.register(Procurement)
class ProcurementAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = ["id", "supplier", "created_by", "total", "status_display", "date"]
    list_filter   = ["status", "date"]
    search_fields = ["supplier__name", "created_by__phone_number"]
    ordering      = ["-date"]
    date_hierarchy = "date"
    readonly_fields = ["date", "total"]
    inlines = [ProcurementItemInline]

    fieldsets = (
        (None, {"fields": ("supplier", "created_by", "status", "total", "date")}),
    )

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)

    actions = ["mark_completed"]

    @admin.action(description="Mark selected procurements as Completed")
    def mark_completed(self, request, queryset):
        updated = queryset.filter(status="draft").update(status="completed")
        self.message_user(request, f"{updated} procurement(s) marked as completed.")


@admin.register(ProcurementItem)
class ProcurementItemAdmin(admin.ModelAdmin):
    list_display  = [
        "item_name", "brand", "dosage_form", "unit",
        "quantity", "cost_price", "markup", "subtotal",
        "expiry_date", "procurement",
    ]
    list_filter   = ["dosage_form", "expiry_date"]
    search_fields = ["item_name", "brand", "barcode"]
    ordering      = ["-procurement__date"]
    readonly_fields = ["subtotal", "procurement"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(procurement__organization=org) if org else qs.none()


# ── Stock Checks ───────────────────────────────────────────────────────────────

class StockCheckItemInline(admin.TabularInline):
    model  = StockCheckItem
    extra  = 0
    readonly_fields = ["item", "expected_quantity", "actual_quantity", "status"]
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(StockCheck)
class StockCheckAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = [
        "id", "created_by", "status_display", "date",
        "approved_by", "approved_at", "item_count",
    ]
    list_filter   = ["status", "date"]
    search_fields = ["created_by__phone_number", "approved_by__phone_number"]
    ordering      = ["-date"]
    date_hierarchy = "date"
    readonly_fields = ["date", "approved_at"]
    inlines = [StockCheckItemInline]

    fieldsets = (
        (None, {"fields": ("created_by", "status", "date")}),
        ("Approval", {
            "fields": ("approved_by", "approved_at"),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)

    @admin.display(description="# Items")
    def item_count(self, obj):
        return obj.stockcheckitem_set.count()

    actions = ["mark_completed"]

    @admin.action(description="Mark selected checks as Completed")
    def mark_completed(self, request, queryset):
        from django.utils.timezone import now as tz_now
        updated = queryset.filter(status="in_progress").update(
            status="completed", approved_at=tz_now()
        )
        self.message_user(request, f"{updated} stock check(s) marked as completed.")


@admin.register(StockCheckItem)
class StockCheckItemAdmin(admin.ModelAdmin):
    list_display  = [
        "stock_check", "item", "expected_quantity",
        "actual_quantity", "discrepancy_display", "status_display",
    ]
    list_filter   = ["status"]
    search_fields = ["item__name", "stock_check__id"]
    ordering      = ["-stock_check__date"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(stock_check__organization=org) if org else qs.none()

    @admin.display(description="Discrepancy")
    def discrepancy_display(self, obj):
        if obj.actual_quantity is None:
            return "—"
        diff = obj.actual_quantity - obj.expected_quantity
        color = "#28a745" if diff == 0 else ("#dc3545" if diff < 0 else "#fd7e14")
        return format_html(
            '<span style="color:{};font-weight:bold">{}</span>', color, f"{diff:+d}"
        )

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)


# ── Notifications ──────────────────────────────────────────────────────────────

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display  = [
        "title", "user", "notif_type", "priority_badge",
        "is_read", "created_at",
    ]
    list_filter   = ["notif_type", "priority", "is_read", "created_at"]
    search_fields = ["title", "message", "user__phone_number"]
    ordering      = ["-created_at"]
    date_hierarchy = "created_at"
    readonly_fields = ["created_at"]

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(user__organization=org) if org else qs.none()

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "user__organization" not in filters:
            filters.insert(0, "user__organization")
        return filters

    @admin.display(description="Priority")
    def priority_badge(self, obj):
        return status_badge(obj.priority)

    actions = ["mark_all_read"]

    @admin.action(description="Mark selected notifications as read")
    def mark_all_read(self, request, queryset):
        updated = queryset.update(is_read=True)
        self.message_user(request, f"{updated} notification(s) marked as read.")


# ── Transfer Requests ──────────────────────────────────────────────────────────

@admin.register(TransferRequest)
class TransferRequestAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = [
        "id", "direction_display", "item_name", "unit",
        "requested_quantity", "approved_quantity",
        "status_display", "requested_by", "approved_by", "created_at",
    ]
    list_filter   = ["status", "from_wholesale", "created_at"]
    search_fields = [
        "item_name", "requested_by__phone_number",
        "approved_by__phone_number", "notes",
    ]
    ordering      = ["-created_at"]
    date_hierarchy = "created_at"
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = (
        ("Transfer", {"fields": ("from_wholesale", "item_name", "unit", "notes")}),
        ("Quantities", {"fields": ("requested_quantity", "approved_quantity")}),
        ("Status & Parties", {"fields": ("status", "requested_by", "approved_by")}),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Direction")
    def direction_display(self, obj):
        if obj.from_wholesale:
            return format_html('<span style="color:#6f42c1">Wholesale → Retail</span>')
        return format_html('<span style="color:#0d6efd">Retail → Wholesale</span>')

    @admin.display(description="Status")
    def status_display(self, obj):
        return status_badge(obj.status)

    actions = ["approve_transfers", "reject_transfers"]

    @admin.action(description="Approve selected transfer requests")
    def approve_transfers(self, request, queryset):
        updated = queryset.filter(status="pending").update(
            status="approved", approved_by=request.user
        )
        self.message_user(request, f"{updated} transfer(s) approved.")

    @admin.action(description="Reject selected transfer requests")
    def reject_transfers(self, request, queryset):
        updated = queryset.filter(status="pending").update(
            status="rejected", approved_by=request.user
        )
        self.message_user(request, f"{updated} transfer(s) rejected.")
