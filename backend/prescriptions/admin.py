from django.contrib import admin
from .models import Hospital, Prescriber, Prescription, PrescriptionItem


# ── Hospital admin ─────────────────────────────────────────────────────────────

@admin.register(Hospital)
class HospitalAdmin(admin.ModelAdmin):
    list_display  = ('name', 'city', 'phone', 'prescriber_count', 'created_at')
    search_fields = ('name', 'city', 'phone')
    readonly_fields = ('created_at',)

    @admin.display(description='Prescribers')
    def prescriber_count(self, obj):
        return obj.prescribers.count()


# ── Custom filters ─────────────────────────────────────────────────────────────

class VerifiedFilter(admin.SimpleListFilter):
    title          = 'verification status'
    parameter_name = 'verified'

    def lookups(self, request, model_admin):
        return [('yes', 'Verified'), ('no', 'Unverified')]

    def queryset(self, request, queryset):
        if self.value() == 'yes':
            return queryset.filter(is_verified=True)
        if self.value() == 'no':
            return queryset.filter(is_verified=False)
        return queryset


# ── Inlines ────────────────────────────────────────────────────────────────────

class PrescriberPrescriptionInline(admin.TabularInline):
    model               = Prescription
    extra               = 0
    fields              = ('id', 'customer_name', 'status', 'organization', 'created_at')
    readonly_fields     = ('id', 'customer_name', 'status', 'organization', 'created_at')
    can_delete          = False
    show_change_link    = True
    verbose_name_plural = 'Prescriptions written'

    def has_add_permission(self, request, obj=None):
        return False


# ── Prescriber admin ───────────────────────────────────────────────────────────

@admin.register(Prescriber)
class PrescriberAdmin(admin.ModelAdmin):
    list_display        = ('name', 'license_number', 'specialty', 'phone', 'hospital', 'verified_badge', 'created_at')
    list_filter         = (VerifiedFilter, 'created_at')
    search_fields       = ('name', 'license_number', 'phone', 'specialty')
    readonly_fields     = ('created_at', 'updated_at')
    raw_id_fields       = ('hospital',)
    list_select_related = ('hospital',)
    date_hierarchy      = 'created_at'
    actions             = ['action_verify', 'action_unverify']

    fieldsets = (
        ('Identity', {
            'fields': ('name', 'license_number', 'specialty'),
        }),
        ('Contact & Location', {
            'fields': ('phone', 'hospital', 'address'),
        }),
        ('Status', {
            'fields': ('is_verified',),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )

    inlines = [PrescriberPrescriptionInline]

    @admin.display(description='Verified', boolean=True, ordering='is_verified')
    def verified_badge(self, obj):
        return obj.is_verified

    @admin.action(description='Mark selected prescribers as verified')
    def action_verify(self, request, queryset):
        updated = queryset.update(is_verified=True)
        self.message_user(request, f'{updated} prescriber(s) marked as verified.')

    @admin.action(description='Mark selected prescribers as unverified')
    def action_unverify(self, request, queryset):
        updated = queryset.update(is_verified=False)
        self.message_user(request, f'{updated} prescriber(s) marked as unverified.')


# ── Prescription admin ─────────────────────────────────────────────────────────

class PrescriptionItemInline(admin.TabularInline):
    model  = PrescriptionItem
    extra  = 0
    fields = ('item_name', 'brand', 'quantity', 'unit', 'dosage',
              'duration', 'is_dispensed', 'dispensed_at', 'dispensed_by')
    readonly_fields = ('dispensed_at',)


@admin.register(Prescription)
class PrescriptionAdmin(admin.ModelAdmin):
    list_display  = ('id', 'customer_name', 'customer_phone', 'status',
                     'organization', 'created_by', 'created_at')
    list_filter   = ('status', 'organization', 'created_at')
    search_fields = ('customer_name', 'customer_phone', 'doctor_name', 'diagnosis')
    readonly_fields = ('created_at', 'dispensed_at')
    inlines       = [PrescriptionItemInline]
    raw_id_fields = ('organization', 'customer', 'created_by', 'branch', 'prescriber')


@admin.register(PrescriptionItem)
class PrescriptionItemAdmin(admin.ModelAdmin):
    list_display  = ('id', 'item_name', 'quantity', 'unit', 'is_dispensed', 'prescription')
    list_filter   = ('is_dispensed',)
    search_fields = ('item_name', 'brand')
    readonly_fields = ('dispensed_at',)
