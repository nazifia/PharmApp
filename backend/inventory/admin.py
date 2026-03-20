from django.contrib import admin
from django.utils.html import format_html
from django.utils.timezone import now

from .models import Item


@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = [
        "name", "brand", "dosage_form", "unit",
        "cost", "price", "markup_display",
        "stock_badge", "store_badge", "status_badge",
        "expiry_display", "created_at",
    ]
    list_filter = [
        "dosage_form", "unit", "store", "status",
        ("expiry_date", admin.DateFieldListFilter),
    ]
    search_fields = ["name", "brand", "barcode", "gtin", "batch_number"]
    ordering = ["name"]
    readonly_fields = ["created_at", "updated_at"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("Product Information", {
            "fields": ("name", "brand", "dosage_form", "unit", "store", "status"),
        }),
        ("Pricing", {
            "fields": ("cost", "markup", "price"),
            "description": "Price is auto-calculated from cost × (1 + markup/100) on save.",
        }),
        ("Stock", {
            "fields": ("stock", "low_stock_threshold"),
        }),
        ("Barcode & Batch", {
            "fields": ("barcode", "barcode_type", "gtin", "batch_number", "serial_number", "expiry_date"),
            "classes": ("collapse",),
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    def markup_display(self, obj):
        return f"{obj.markup}%"
    markup_display.short_description = "Markup"

    def stock_badge(self, obj):
        if obj.stock <= 0:
            color, label = "#dc3545", f"OUT ({obj.stock})"
        elif obj.stock <= obj.low_stock_threshold:
            color, label = "#fd7e14", f"LOW ({obj.stock})"
        else:
            color, label = "#28a745", str(obj.stock)
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:4px;font-size:11px">{}</span>',
            color, label
        )
    stock_badge.short_description = "Stock"

    def store_badge(self, obj):
        colors = {"retail": "#0d6efd", "wholesale": "#6f42c1"}
        color = colors.get(obj.store, "#6c757d")
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:4px;font-size:11px">{}</span>',
            color, obj.store.title()
        )
    store_badge.short_description = "Store"

    def status_badge(self, obj):
        colors = {"active": "#28a745", "inactive": "#6c757d", "discontinued": "#dc3545"}
        color = colors.get(obj.status, "#6c757d")
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:4px;font-size:11px">{}</span>',
            color, obj.status.title()
        )
    status_badge.short_description = "Status"

    def expiry_display(self, obj):
        if not obj.expiry_date:
            return "—"
        today = now().date()
        days = (obj.expiry_date - today).days
        if days < 0:
            color = "#dc3545"
            label = f"{obj.expiry_date} (expired)"
        elif days <= 30:
            color = "#fd7e14"
            label = f"{obj.expiry_date} ({days}d)"
        elif days <= 90:
            color = "#ffc107"
            label = f"{obj.expiry_date} ({days}d)"
        else:
            color = "#28a745"
            label = str(obj.expiry_date)
        return format_html('<span style="color:{}">{}</span>', color, label)
    expiry_display.short_description = "Expiry"

    actions = [
        "mark_active", "mark_inactive",
        "move_to_retail", "move_to_wholesale",
    ]

    @admin.action(description="Mark selected items as Active")
    def mark_active(self, request, queryset):
        updated = queryset.update(status="active")
        self.message_user(request, f"{updated} item(s) marked as active.")

    @admin.action(description="Mark selected items as Inactive")
    def mark_inactive(self, request, queryset):
        updated = queryset.update(status="inactive")
        self.message_user(request, f"{updated} item(s) marked as inactive.")

    @admin.action(description="Move selected items to Retail store")
    def move_to_retail(self, request, queryset):
        updated = queryset.update(store="retail")
        self.message_user(request, f"{updated} item(s) moved to retail store.")

    @admin.action(description="Move selected items to Wholesale store")
    def move_to_wholesale(self, request, queryset):
        updated = queryset.update(store="wholesale")
        self.message_user(request, f"{updated} item(s) moved to wholesale store.")
