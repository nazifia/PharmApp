from django.contrib import admin
from django.utils.html import format_html
from django.db import transaction

from .models import Branch


# ── Inline (used inside OrganizationAdmin) ───────────────────────────────────

class BranchInline(admin.TabularInline):
    model       = Branch
    extra       = 0
    fields      = ('name', 'address', 'phone', 'email', 'is_main', 'is_active')
    readonly_fields = ()
    show_change_link = True
    verbose_name        = 'Branch'
    verbose_name_plural = 'Branches'
    ordering = ('-is_main', 'name')


# ── Standalone admin ─────────────────────────────────────────────────────────

@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display   = (
        'name', 'organization', 'org_plan_badge',
        'address_short', 'phone',
        'main_badge', 'active_badge', 'created_at',
    )
    list_filter    = ('is_active', 'is_main', 'organization')
    search_fields  = ('name', 'organization__name', 'phone', 'address', 'email')
    readonly_fields = ('created_at', 'updated_at')
    ordering       = ('organization__name', '-is_main', 'name')
    actions        = ['action_set_main', 'action_activate', 'action_deactivate']

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

    # ── Computed columns ──────────────────────────────────────────────────────

    @admin.display(description='Plan', ordering='organization__subscription__plan')
    def org_plan_badge(self, obj):
        try:
            sub = obj.organization.subscription
            colors = {
                'trial':        '#F59E0B',
                'starter':      '#3B82F6',
                'professional': '#8B5CF6',
                'enterprise':   '#06B6D4',
            }
            c = colors.get(sub.plan, '#6B7280')
            return format_html(
                '<span style="background:{};color:#fff;padding:2px 7px;'
                'border-radius:10px;font-size:11px;font-weight:600">{}</span>',
                c, sub.get_plan_display(),
            )
        except Exception:
            return format_html('<span style="color:#94a3b8;font-size:11px">—</span>')

    @admin.display(description='Main?', boolean=False, ordering='is_main')
    def main_badge(self, obj):
        if obj.is_main:
            return format_html(
                '<span style="background:#0D9488;color:#fff;padding:2px 8px;'
                'border-radius:10px;font-size:11px;font-weight:700">Main</span>'
            )
        return format_html('<span style="color:#94a3b8;font-size:11px">—</span>')

    @admin.display(description='Active?', boolean=False, ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html(
                '<span style="background:#10B981;color:#fff;padding:2px 8px;'
                'border-radius:10px;font-size:11px">Active</span>'
            )
        return format_html(
            '<span style="background:#EF4444;color:#fff;padding:2px 8px;'
            'border-radius:10px;font-size:11px">Inactive</span>'
        )

    @admin.display(description='Address')
    def address_short(self, obj):
        return (obj.address[:40] + '…') if len(obj.address) > 40 else obj.address or '—'

    # ── Actions ───────────────────────────────────────────────────────────────

    @admin.action(description='Set selected branch as Main for its org')
    def action_set_main(self, request, queryset):
        updated = 0
        for branch in queryset.select_related('organization'):
            if not branch.is_active:
                self.message_user(
                    request,
                    f'"{branch.name}" is inactive — cannot set as main.',
                    level='warning',
                )
                continue
            with transaction.atomic():
                Branch.objects.filter(
                    organization=branch.organization, is_main=True
                ).update(is_main=False)
                branch.is_main = True
                branch.save(update_fields=['is_main', 'updated_at'])
            updated += 1
        if updated:
            self.message_user(request, f'{updated} branch(es) set as main.')

    @admin.action(description='Activate selected branches')
    def action_activate(self, request, queryset):
        count = queryset.update(is_active=True)
        self.message_user(request, f'{count} branch(es) activated.')

    @admin.action(description='Deactivate selected branches')
    def action_deactivate(self, request, queryset):
        protected = []
        deactivated = 0
        for branch in queryset.select_related('organization'):
            if branch.is_main:
                other = Branch.objects.filter(
                    organization=branch.organization, is_active=True
                ).exclude(pk=branch.pk).exists()
                if other:
                    protected.append(branch.name)
                    continue
            branch.is_active = False
            branch.save(update_fields=['is_active', 'updated_at'])
            deactivated += 1
        if deactivated:
            self.message_user(request, f'{deactivated} branch(es) deactivated.')
        for name in protected:
            self.message_user(
                request,
                f'"{name}" is the main branch with other active branches — set another as main first.',
                level='warning',
            )

    # ── Superuser-only permissions ────────────────────────────────────────────

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_add_permission(self, request):
        return request.user.is_superuser

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser
