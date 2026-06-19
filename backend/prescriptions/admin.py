from django.contrib import admin
from django.utils.html import format_html
from authapp.admin_mixins import OrgScopedAdminMixin
from .models import (
    Hospital, Prescriber, Prescription, PrescriptionItem,
    PrescriberCommission, ConsultationPayout,
)


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


class SelfRegisteredFilter(admin.SimpleListFilter):
    """
    Filters by registration source.
    Self-registered prescribers (via public /register/ endpoint) have a
    non-empty password hash set. Staff-added ones have password=''.
    """
    title          = 'registration source'
    parameter_name = 'reg_source'

    def lookups(self, request, model_admin):
        return [
            ('self', 'Self-registered (public form)'),
            ('staff', 'Staff-added'),
        ]

    def queryset(self, request, queryset):
        if self.value() == 'self':
            return queryset.exclude(password='')
        if self.value() == 'staff':
            return queryset.filter(password='')
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
    list_display        = (
        'name', 'license_number', 'specialty', 'phone',
        'hospital', 'organization', 'reg_source_badge',
        'verified_badge', 'created_at',
    )
    list_filter         = (VerifiedFilter, SelfRegisteredFilter, 'created_at')

    def get_queryset(self, request):
        """
        Org-staff visibility mirrors the API contract (Prescriber docstring):
        global prescribers (no org), the staff member's own org, and any
        network-shared prescriber. Other orgs' private prescribers — which
        carry PII (phone, licence, address) — stay hidden. Superusers see all.
        """
        from django.db.models import Q
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        if org is None:
            return qs.filter(organization__isnull=True)
        return qs.filter(
            Q(organization__isnull=True)
            | Q(organization=org)
            | Q(is_network_shared=True)
        )
    search_fields       = ('name', 'license_number', 'phone', 'specialty', 'organization__name')
    readonly_fields     = ('created_at', 'updated_at', 'reg_source_display', 'password_status')
    raw_id_fields       = ('hospital', 'organization')
    list_select_related = ('hospital', 'organization')
    date_hierarchy      = 'created_at'
    actions             = ['action_verify', 'action_unverify', 'action_clear_password']

    fieldsets = (
        ('Identity', {
            'fields': ('name', 'license_number', 'specialty'),
        }),
        ('Contact & Location', {
            'fields': ('phone', 'hospital', 'address'),
        }),
        ('Organisation', {
            'fields': ('organization', 'is_network_shared'),
            'description': (
                'Organization is optional. Global prescribers (no org) are visible to all pharmacies. '
                'Set org only if this prescriber is exclusive to one pharmacy.'
            ),
        }),
        ('Status', {
            'fields': ('is_verified', 'commission_rate'),
        }),
        ('Registration', {
            'fields': ('reg_source_display', 'password_status'),
            'description': (
                'Self-registered prescribers arrive via the public registration form '
                'and require admin verification before pharmacies can use them. '
                'Use "Clear password" bulk action to revoke self-registration credentials.'
            ),
        }),
        ('Legacy / Compatibility', {
            'fields': ('clinic',),
            'classes': ('collapse',),
            'description': 'clinic is a free-text fallback kept for backward compatibility. Prefer the hospital FK above.',
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )

    inlines = [PrescriberPrescriptionInline]

    # ── Computed display helpers ───────────────────────────────────────────────

    @admin.display(description='Verified', boolean=True, ordering='is_verified')
    def verified_badge(self, obj):
        return obj.is_verified

    @admin.display(description='Source')
    def reg_source_badge(self, obj):
        if obj.password:
            return format_html(
                '<span style="color:#d97706;font-weight:bold">Self-reg</span>'
            )
        return format_html('<span style="color:#6b7280">Staff</span>')

    @admin.display(description='Registration source')
    def reg_source_display(self, obj):
        if obj.password:
            return 'Self-registered via public form (password set). Requires verification.'
        return 'Added by pharmacy staff.'

    @admin.display(description='Password status')
    def password_status(self, obj):
        if obj.password:
            return format_html(
                '<span style="color:#d97706">Password set (self-registration credential active)</span>'
            )
        return format_html('<span style="color:#6b7280">No password (staff-added record)</span>')

    # ── Bulk actions ───────────────────────────────────────────────────────────

    @admin.action(description='Mark selected prescribers as verified')
    def action_verify(self, request, queryset):
        updated = queryset.update(is_verified=True)
        self.message_user(request, f'{updated} prescriber(s) marked as verified.')

    @admin.action(description='Mark selected prescribers as unverified')
    def action_unverify(self, request, queryset):
        updated = queryset.update(is_verified=False)
        self.message_user(request, f'{updated} prescriber(s) marked as unverified.')

    @admin.action(description='Clear password (revoke self-registration credential)')
    def action_clear_password(self, request, queryset):
        updated = queryset.exclude(password='').update(password='')
        self.message_user(
            request,
            f'Password cleared for {updated} prescriber(s). '
            'They can no longer log in via the self-registration portal.'
        )


# ── Prescription admin ─────────────────────────────────────────────────────────

class PrescriptionItemInline(admin.TabularInline):
    model  = PrescriptionItem
    extra  = 0
    fields = ('item_name', 'brand', 'quantity', 'unit', 'dosage',
              'duration', 'is_dispensed', 'dispensed_at', 'dispensed_by')
    readonly_fields = ('dispensed_at',)


@admin.register(Prescription)
class PrescriptionAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
    list_display  = ('id', 'customer_name', 'customer_phone', 'status',
                     'organization', 'created_by', 'created_at')
    list_filter   = ('status', 'created_at')
    search_fields = ('customer_name', 'customer_phone', 'doctor_name', 'diagnosis')
    readonly_fields = ('created_at', 'dispensed_at')
    inlines       = [PrescriptionItemInline]
    raw_id_fields = ('customer', 'created_by', 'branch', 'prescriber')

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "organization" not in filters:
            filters.insert(0, "organization")
        return filters


@admin.register(PrescriptionItem)
class PrescriptionItemAdmin(admin.ModelAdmin):
    list_display  = ('id', 'item_name', 'quantity', 'unit', 'is_dispensed', 'prescription')
    list_filter   = ('is_dispensed',)
    search_fields = ('item_name', 'brand')
    readonly_fields = ('dispensed_at',)

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(prescription__organization=org) if org else qs.none()


@admin.register(PrescriberCommission)
class PrescriberCommissionAdmin(admin.ModelAdmin):
    list_display    = (
        'id', 'prescriber', 'prescription', 'patient_name',
        'commission_amount', 'status', 'paid_at', 'created_at',
    )
    list_filter     = ('status', 'created_at')
    search_fields   = ('prescriber__name', 'patient_name')
    readonly_fields = ('created_at', 'sales_amount', 'commission_rate', 'commission_amount')
    raw_id_fields   = ('prescriber', 'prescription')
    actions         = ['action_mark_paid', 'action_mark_pending']

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(prescription__organization=org) if org else qs.none()

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "prescription__organization" not in filters:
            filters.insert(0, "prescription__organization")
        return filters

    @admin.action(description='Mark selected commissions as paid')
    def action_mark_paid(self, request, queryset):
        from django.utils import timezone
        updated = queryset.filter(status='pending').update(status='paid', paid_at=timezone.now())
        self.message_user(request, f'{updated} commission(s) marked as paid.')

    @admin.action(description='Mark selected commissions as pending')
    def action_mark_pending(self, request, queryset):
        updated = queryset.filter(status='paid').update(status='pending', paid_at=None)
        self.message_user(request, f'{updated} commission(s) reset to pending.')


@admin.register(ConsultationPayout)
class ConsultationPayoutAdmin(admin.ModelAdmin):
    list_display    = (
        'id', 'prescriber', 'prescription', 'patient_name',
        'consultation_category', 'consultation_fee', 'status', 'paid_at', 'created_at',
    )
    list_filter     = ('status', 'consultation_category', 'created_at')
    search_fields   = ('prescriber__name', 'patient_name')
    readonly_fields = ('created_at', 'consultation_category', 'consultation_fee')
    raw_id_fields   = ('prescriber', 'prescription')
    actions         = ['action_mark_paid', 'action_mark_pending']

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        org = getattr(request.user, "organization", None)
        return qs.filter(prescription__organization=org) if org else qs.none()

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "prescription__organization" not in filters:
            filters.insert(0, "prescription__organization")
        return filters

    @admin.action(description='Mark selected payouts as paid')
    def action_mark_paid(self, request, queryset):
        from django.utils import timezone
        updated = queryset.filter(status='pending').update(status='paid', paid_at=timezone.now())
        self.message_user(request, f'{updated} consultation payout(s) marked as paid.')

    @admin.action(description='Mark selected payouts as pending')
    def action_mark_pending(self, request, queryset):
        updated = queryset.filter(status='paid').update(status='pending', paid_at=None)
        self.message_user(request, f'{updated} consultation payout(s) reset to pending.')
