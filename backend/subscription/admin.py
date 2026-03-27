from django.contrib import admin
from django.utils.html import format_html
from .models import Subscription


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display  = ('organization', 'plan_badge', 'status_badge', 'trial_ends_at', 'current_period_end', 'updated_at')
    list_filter   = ('plan', 'status')
    search_fields = ('organization__name', 'organization__slug', 'external_subscription_id')
    readonly_fields = ('created_at', 'updated_at')
    ordering      = ('-created_at',)

    fieldsets = (
        ('Organization', {
            'fields': ('organization',)
        }),
        ('Plan', {
            'fields': ('plan', 'status', 'trial_ends_at', 'current_period_end')
        }),
        ('Payment Integration', {
            'fields': ('external_subscription_id',),
            'classes': ('collapse',),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )

    def plan_badge(self, obj):
        colors = {
            'trial':        '#F59E0B',
            'starter':      '#3B82F6',
            'professional': '#8B5CF6',
            'enterprise':   '#06B6D4',
        }
        color = colors.get(obj.plan, '#6B7280')
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;border-radius:10px;font-size:11px">{}</span>',
            color, obj.get_plan_display()
        )
    plan_badge.short_description = 'Plan'

    def status_badge(self, obj):
        colors = {
            'active':    '#10B981',
            'trial':     '#3B82F6',
            'expiring':  '#F59E0B',
            'expired':   '#EF4444',
            'suspended': '#EF4444',
            'cancelled': '#6B7280',
        }
        color = colors.get(obj.status, '#6B7280')
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;border-radius:10px;font-size:11px">{}</span>',
            color, obj.get_status_display()
        )
    status_badge.short_description = 'Status'
