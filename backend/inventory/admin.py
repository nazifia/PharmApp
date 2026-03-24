from django.contrib import admin
from django.db.models import Count, F, FloatField, Q, Sum
from django.utils.html import format_html
from django.utils.timezone import now

from authapp.admin_mixins import OrgScopedAdminMixin
from .models import Item, RetailItem, WholesaleItem


# ── Custom list filters ───────────────────────────────────────────────────────

class StockStatusFilter(admin.SimpleListFilter):
    title = "Stock Status"
    parameter_name = "stock_status"

    def lookups(self, request, model_admin):
        return [
            ("out",  "Out of Stock"),
            ("low",  "Low Stock"),
            ("ok",   "In Stock"),
        ]

    def queryset(self, request, queryset):
        if self.value() == "out":
            return queryset.filter(stock__lte=0)
        if self.value() == "low":
            return queryset.filter(stock__gt=0, stock__lte=models_low_threshold(queryset))
        if self.value() == "ok":
            return queryset.filter(stock__gt=0).exclude(stock__lte=0)
        return queryset


def models_low_threshold(qs):
    """Return a subquery-safe threshold — we filter item-by-item via Python."""
    return 0  # placeholder; real filtering done below via override


class StockStatusFilter(admin.SimpleListFilter):
    """Filter items by stock level relative to their own low_stock_threshold."""
    title = "Stock Status"
    parameter_name = "stock_status"

    def lookups(self, request, model_admin):
        return [
            ("out", "Out of Stock"),
            ("low", "Low Stock"),
            ("ok",  "In Stock"),
        ]

    def queryset(self, request, queryset):
        if self.value() == "out":
            return queryset.filter(stock__lte=0)
        if self.value() == "low":
            # stock > 0 AND stock <= low_stock_threshold
            return queryset.filter(stock__gt=0).extra(
                where=["stock <= low_stock_threshold"]
            )
        if self.value() == "ok":
            # stock > low_stock_threshold
            return queryset.extra(where=["stock > low_stock_threshold"])
        return queryset


# ── Shared helpers ────────────────────────────────────────────────────────────

def _badge(label, color):
    return format_html(
        '<span style="background:{};color:#fff;padding:2px 8px;'
        'border-radius:4px;font-size:11px;font-weight:600">{}</span>',
        color, label,
    )


def _stock_badge(obj):
    if obj.stock <= 0:
        return _badge(f"OUT ({obj.stock})", "#dc3545")
    if obj.stock <= obj.low_stock_threshold:
        return _badge(f"LOW ({obj.stock})", "#fd7e14")
    return _badge(str(obj.stock), "#28a745")


def _store_badge(obj):
    colors = {"retail": "#0d6efd", "wholesale": "#6f42c1"}
    return _badge(obj.store.title(), colors.get(obj.store, "#6c757d"))


def _status_badge(obj):
    colors = {"active": "#28a745", "inactive": "#6c757d"}
    return _badge(obj.status.title(), colors.get(obj.status, "#6c757d"))


def _expiry_display(obj):
    if not obj.expiry_date:
        return "—"
    today = now().date()
    days = (obj.expiry_date - today).days
    if days < 0:
        color, label = "#dc3545", f"{obj.expiry_date} (expired)"
    elif days <= 30:
        color, label = "#fd7e14", f"{obj.expiry_date} ({days}d)"
    elif days <= 90:
        color, label = "#ffc107", f"{obj.expiry_date} ({days}d)"
    else:
        color, label = "#28a745", str(obj.expiry_date)
    return format_html('<span style="color:{}">{}</span>', color, label)


# ── Shared actions ────────────────────────────────────────────────────────────

@admin.action(description="Mark selected items as Active")
def mark_active(modeladmin, request, queryset):
    updated = queryset.update(status="active")
    modeladmin.message_user(request, f"{updated} item(s) marked as active.")


@admin.action(description="Mark selected items as Inactive")
def mark_inactive(modeladmin, request, queryset):
    updated = queryset.update(status="inactive")
    modeladmin.message_user(request, f"{updated} item(s) marked as inactive.")


@admin.action(description="Move selected items → Retail store")
def move_to_retail(modeladmin, request, queryset):
    updated = queryset.update(store="retail")
    modeladmin.message_user(request, f"{updated} item(s) moved to Retail store.")


@admin.action(description="Move selected items → Wholesale store")
def move_to_wholesale(modeladmin, request, queryset):
    updated = queryset.update(store="wholesale")
    modeladmin.message_user(request, f"{updated} item(s) moved to Wholesale store.")


@admin.action(description="Top up stock by +10 units")
def topup_stock_10(modeladmin, request, queryset):
    for item in queryset:
        item.stock += 10
        item.save(update_fields=["stock"])
    modeladmin.message_user(request, f"{queryset.count()} item(s) topped up by 10 units.")


@admin.action(description="Top up stock by +50 units")
def topup_stock_50(modeladmin, request, queryset):
    for item in queryset:
        item.stock += 50
        item.save(update_fields=["stock"])
    modeladmin.message_user(request, f"{queryset.count()} item(s) topped up by 50 units.")


@admin.action(description="Reset out-of-stock items to 1 unit")
def reset_to_one(modeladmin, request, queryset):
    updated = queryset.filter(stock__lte=0).update(stock=1)
    modeladmin.message_user(request, f"{updated} out-of-stock item(s) reset to 1 unit.")


# ── Base ItemAdmin mixin ──────────────────────────────────────────────────────

class BaseItemAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = [
        "name", "brand", "dosage_form", "unit",
        "cost", "price", "markup_pct",
        "stock_display", "store_display", "status_display",
        "expiry_col", "created_at",
    ]
    list_filter   = [
        StockStatusFilter,
        "dosage_form", "unit", "store", "status",
        ("expiry_date", admin.DateFieldListFilter),
    ]
    search_fields = ["name", "brand", "barcode", "gtin", "batch_number"]
    ordering      = ["name"]
    readonly_fields   = ["created_at", "updated_at"]
    date_hierarchy    = "created_at"
    list_per_page     = 30
    list_display_links = ["name"]
    show_full_result_count = True

    fieldsets = (
        ("Product Information", {
            "fields": ("name", "brand", "dosage_form", "unit", "store", "status"),
        }),
        ("Pricing", {
            "fields": ("cost", "markup", "price"),
            "description": "Price is auto-calculated from cost × (1 + markup/100) on first save.",
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

    actions = [
        mark_active, mark_inactive,
        move_to_retail, move_to_wholesale,
        topup_stock_10, topup_stock_50, reset_to_one,
    ]

    # ── Column helpers ────────────────────────────────────────────────────────

    @admin.display(description="Markup", ordering="markup")
    def markup_pct(self, obj):
        return f"{obj.markup}%"

    @admin.display(description="Stock", ordering="stock")
    def stock_display(self, obj):
        return _stock_badge(obj)
    stock_display.allow_tags = True

    @admin.display(description="Store", ordering="store")
    def store_display(self, obj):
        return _store_badge(obj)

    @admin.display(description="Status", ordering="status")
    def status_display(self, obj):
        return _status_badge(obj)

    @admin.display(description="Expiry", ordering="expiry_date")
    def expiry_col(self, obj):
        return _expiry_display(obj)

    # ── Changelist stats banner ───────────────────────────────────────────────

    def _stats_html(self, qs):
        total    = qs.count()
        out      = qs.filter(stock__lte=0).count()
        low      = qs.filter(stock__gt=0).extra(where=["stock <= low_stock_threshold"]).count()
        in_stock = total - out - low
        stock_val = qs.aggregate(v=Sum(F("stock") * F("price"), output_field=FloatField()))["v"] or 0

        def pill(label, val, color):
            return (
                f'<span style="display:inline-block;background:{color}20;color:{color};'
                f'border:1px solid {color}60;border-radius:6px;padding:4px 12px;'
                f'margin:0 4px 4px 0;font-size:12px;font-weight:600">'
                f'{label}: <strong>{val}</strong></span>'
            )

        html = (
            '<div style="background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;'
            'padding:12px 16px;margin-bottom:12px">'
            '<strong style="font-size:13px">Inventory Summary</strong>&nbsp;&nbsp;'
            + pill("Total",    total,    "#0d6efd")
            + pill("In Stock", in_stock, "#28a745")
            + pill("Low",      low,      "#fd7e14")
            + pill("Out",      out,      "#dc3545")
            + pill("Stock Value", f"₦{float(stock_val):,.0f}", "#6f42c1")
            + '</div>'
        )
        return format_html(html)

    def changelist_view(self, request, extra_context=None):
        extra_context = extra_context or {}
        qs = self.get_queryset(request)
        extra_context["inventory_stats"] = self._stats_html(qs)
        return super().changelist_view(request, extra_context=extra_context)

    class Media:
        css = {}

    # Inject the stats banner above the changelist results table.
    change_list_template = "admin/inventory_changelist.html"


# ── Main ItemAdmin (all stores) ───────────────────────────────────────────────

@admin.register(Item)
class ItemAdmin(BaseItemAdmin):
    pass


# ── Retail-only admin ─────────────────────────────────────────────────────────

@admin.register(RetailItem)
class RetailItemAdmin(BaseItemAdmin):
    actions = [
        mark_active, mark_inactive,
        move_to_wholesale,          # only move-to-wholesale makes sense here
        topup_stock_10, topup_stock_50, reset_to_one,
    ]

    def get_queryset(self, request):
        return super().get_queryset(request).filter(store="retail")

    def save_model(self, request, obj, form, change):
        obj.store = "retail"
        super().save_model(request, obj, form, change)


# ── Wholesale-only admin ──────────────────────────────────────────────────────

@admin.register(WholesaleItem)
class WholesaleItemAdmin(BaseItemAdmin):
    actions = [
        mark_active, mark_inactive,
        move_to_retail,             # only move-to-retail makes sense here
        topup_stock_10, topup_stock_50, reset_to_one,
    ]

    def get_queryset(self, request):
        return super().get_queryset(request).filter(store="wholesale")

    def save_model(self, request, obj, form, change):
        obj.store = "wholesale"
        super().save_model(request, obj, form, change)
