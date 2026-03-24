"""
OrgScopedAdminMixin — per-organisation data isolation in Django admin.

Rules
─────
• Superusers  (is_superuser=True)       → see ALL organisations' data.
• Org staff   (is_staff=True, org set)  → see ONLY their own organisation.
• Staff with no org assigned            → see nothing (empty queryset).

Usage
─────
    class MyModelAdmin(OrgScopedAdminMixin, admin.ModelAdmin):
        org_field = "organization"   # FK field on the model; default is "organization"

For models whose organisation is reached through a relation (e.g. sale__organization)
override get_queryset in the admin class and call self._org_filter(request, qs, lookup).
"""
from __future__ import annotations


class OrgScopedAdminMixin:
    """
    Drop-in mixin for ModelAdmin classes whose model has a direct ForeignKey to
    authapp.Organization.  Apply before admin.ModelAdmin in the MRO:

        class FooAdmin(OrgScopedAdminMixin, admin.ModelAdmin): ...
    """

    #: FK field name on the model.  Override when it differs from "organization".
    org_field: str = "organization"

    # ── Internal helpers ──────────────────────────────────────────────────────

    @staticmethod
    def _user_org(request):
        """
        Return the logged-in user's Organisation object.
        Returns None for superusers (→ no filter).
        Returns the Organisation for org-staff.
        Returns a sentinel ``_NO_ORG`` object (falsy) for staff with no org.
        """
        if request.user.is_superuser:
            return None
        return getattr(request.user, "organization", None)

    def _org_filter(self, request, queryset, lookup: str | None = None):
        """
        Apply an organisation filter to *queryset*.

        *lookup* defaults to ``self.org_field`` but may be an ORM traversal
        string such as ``"sale__organization"`` for models without a direct org FK.
        Returns an empty queryset when the user is staff but has no organisation.
        """
        if request.user.is_superuser:
            return queryset                     # superuser → unfiltered
        org = getattr(request.user, "organization", None)
        if org is None:
            return queryset.none()              # staff with no org → see nothing
        field = lookup or self.org_field
        return queryset.filter(**{field: org})

    # ── Core overrides ────────────────────────────────────────────────────────

    def get_queryset(self, request):
        return self._org_filter(request, super().get_queryset(request))

    def save_model(self, request, obj, form, change):
        """Auto-assign the user's organisation when creating a new record."""
        if not change:
            org = self._user_org(request)
            if org and not getattr(obj, self.org_field, None):
                setattr(obj, self.org_field, org)
        super().save_model(request, obj, form, change)

    # ── Dynamic list_display / list_filter (superusers only) ─────────────────

    def get_list_display(self, request):
        cols = list(super().get_list_display(request))
        if request.user.is_superuser and "organization" not in cols:
            cols.insert(1, "organization")
        return cols

    def get_list_filter(self, request):
        filters = list(super().get_list_filter(request))
        if request.user.is_superuser and "organization" not in filters:
            filters.insert(0, "organization")
        return filters

    # ── FK dropdown scoping ───────────────────────────────────────────────────

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        org = self._user_org(request)
        if org is not None:
            # Lazy imports to avoid circular dependencies
            from django.contrib.auth import get_user_model
            from authapp.models import Organization
            User = get_user_model()

            related = db_field.related_model
            if related == Organization:
                kwargs.setdefault(
                    "queryset", Organization.objects.filter(pk=org.pk)
                )
            elif related == User:
                kwargs.setdefault(
                    "queryset", User.objects.filter(organization=org)
                )
            elif related.__name__ == "Customer":
                kwargs.setdefault(
                    "queryset", related.objects.filter(organization=org)
                )
            elif related.__name__ == "Item":
                kwargs.setdefault(
                    "queryset", related.objects.filter(organization=org)
                )
            elif related.__name__ == "Supplier":
                kwargs.setdefault(
                    "queryset", related.objects.filter(organization=org)
                )
            elif related.__name__ == "Cashier":
                kwargs.setdefault(
                    "queryset", related.objects.filter(user__organization=org)
                )
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


class OrgScopedInlineMixin:
    """
    Mixin for TabularInline / StackedInline.
    Scopes FK dropdowns to the current user's organisation.
    (Inline row queryset is implicitly scoped via the parent object.)
    """

    @staticmethod
    def _user_org(request):
        if request.user.is_superuser:
            return None
        return getattr(request.user, "organization", None)

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        org = self._user_org(request)
        if org is not None:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            related = db_field.related_model
            if related == User:
                kwargs.setdefault(
                    "queryset", User.objects.filter(organization=org)
                )
            elif related.__name__ == "Item":
                kwargs.setdefault(
                    "queryset", related.objects.filter(organization=org)
                )
            elif related.__name__ == "Customer":
                kwargs.setdefault(
                    "queryset", related.objects.filter(organization=org)
                )
        return super().formfield_for_foreignkey(db_field, request, **kwargs)
