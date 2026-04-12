from django.contrib import admin
from .models import Branch


@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display  = ('name', 'organization', 'phone', 'is_main', 'is_active', 'created_at')
    list_filter   = ('is_active', 'is_main', 'organization')
    search_fields = ('name', 'organization__name', 'phone', 'address')
    readonly_fields = ('created_at', 'updated_at')
    fieldsets = (
        (None, {
            'fields': ('organization', 'name', 'address', 'phone', 'email'),
        }),
        ('Flags', {
            'fields': ('is_main', 'is_active'),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )
