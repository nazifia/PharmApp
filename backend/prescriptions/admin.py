from django.contrib import admin
from .models import Prescription, PrescriptionItem


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
    raw_id_fields = ('organization', 'customer', 'created_by', 'branch')


@admin.register(PrescriptionItem)
class PrescriptionItemAdmin(admin.ModelAdmin):
    list_display  = ('id', 'item_name', 'quantity', 'unit', 'is_dispensed', 'prescription')
    list_filter   = ('is_dispensed',)
    search_fields = ('item_name', 'brand')
    readonly_fields = ('dispensed_at',)
