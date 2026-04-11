"""
Role-Based Access Control — DRF Permission classes.

Usage in any API view:
    @api_view(['GET'])
    @permission_classes([IsAuthenticated, IsAdminOrManager])
    def my_view(request): ...

Or as a helper:
    from authapp.permissions import require_role
    err = require_role(request, REPORTS_ROLES)
    if err: return err
"""

from rest_framework.permissions import BasePermission
from rest_framework.response import Response
from rest_framework import status

# ── Role sets ──────────────────────────────────────────────────────────────────

ADMIN_ONLY = {"Admin"}
SENIOR_ROLES = {"Admin", "Manager"}
INVENTORY_WRITE = {"Admin", "Manager", "Pharmacist", "Wholesale Manager"}
INVENTORY_READ = {
    "Admin",
    "Manager",
    "Pharmacist",
    "Pharm-Tech",
    "Salesperson",
    "Cashier",
    "Wholesale Manager",
    "Wholesale Operator",
    "Wholesale Salesperson",
}
RETAIL_POS = {"Admin", "Manager", "Pharmacist", "Pharm-Tech", "Salesperson", "Cashier"}
WHOLESALE_POS = {
    "Admin",
    "Manager",
    "Wholesale Manager",
    "Wholesale Operator",
    "Wholesale Salesperson",
}
ALL_STAFF = RETAIL_POS | WHOLESALE_POS  # every non-anonymous role
CUSTOMERS_WRITE = {"Admin", "Manager", "Pharmacist", "Pharm-Tech", "Wholesale Manager"}
CUSTOMERS_READ = ALL_STAFF
EXPENSES_ROLES = {"Admin", "Manager", "Wholesale Manager"}
SUPPLIERS_ROLES = {"Admin", "Manager", "Pharmacist", "Wholesale Manager"}
PAYMENTS_ROLES = {"Admin", "Manager", "Pharmacist", "Wholesale Manager"}
REPORTS_ROLES = SENIOR_ROLES
TRANSFERS_ROLES = {
    "Admin",
    "Manager",
    "Pharmacist",
    "Pharm-Tech",
    "Salesperson",
    "Wholesale Manager",
    "Wholesale Operator",
    "Wholesale Salesperson",
}
NOTIFICATIONS_ROLES = SENIOR_ROLES
SUBSCRIPTION_ROLES = SENIOR_ROLES

# Human-readable labels ordered for display (matches Flutter AppPermission keys)
PERMISSION_LABELS = [
    ("Reports & Analytics", "viewReports"),
    ("User Management", "manageUsers"),
    ("Settings", "manageSettings"),
    ("Notifications", "viewNotifications"),
    ("Subscription", "viewSubscription"),
    ("Retail POS", "retailPOS"),
    ("Wholesale POS", "wholesalePOS"),
    ("Wholesale Section", "viewWholesale"),
    ("Read Inventory", "readInventory"),
    ("Write Inventory", "writeInventory"),
    ("Read Customers", "readCustomers"),
    ("Write Customers", "writeCustomers"),
    ("Manage Expenses", "manageExpenses"),
    ("Manage Suppliers", "manageSuppliers"),
    ("Process Payments", "processPayments"),
    ("Manage Transfers", "manageTransfers"),
]


# ── DRF Permission classes ─────────────────────────────────────────────────────


def _role(request) -> str:
    return getattr(request.user, "role", "") or ""


class IsAdminOnly(BasePermission):
    message = "Only Admins can perform this action."

    def has_permission(self, request, view):
        return _role(request) in ADMIN_ONLY


class IsAdminOrManager(BasePermission):
    message = "Only Admin or Manager roles can access this resource."

    def has_permission(self, request, view):
        return _role(request) in SENIOR_ROLES


class IsRetailStaff(BasePermission):
    message = "Your role does not have access to the retail module."

    def has_permission(self, request, view):
        return _role(request) in RETAIL_POS


class IsWholesaleStaff(BasePermission):
    message = "Your role does not have access to the wholesale module."

    def has_permission(self, request, view):
        return _role(request) in WHOLESALE_POS


class IsInventoryEditor(BasePermission):
    """
    Read (GET/HEAD/OPTIONS): any authenticated user.
    Write (POST/PUT/PATCH/DELETE): Admin, Manager, Pharmacist, Wholesale Manager.
    """

    message = "Your role cannot modify inventory."

    def has_permission(self, request, view):
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return _role(request) in INVENTORY_READ
        return _role(request) in INVENTORY_WRITE


class IsCustomerEditor(BasePermission):
    """Read: all staff.  Write: Admin, Manager, Pharmacist, Pharm-Tech, WS Manager."""

    message = "Your role cannot modify customer records."

    def has_permission(self, request, view):
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return _role(request) in CUSTOMERS_READ
        return _role(request) in CUSTOMERS_WRITE


# ── Functional helper (use when you need an inline check) ─────────────────────


def require_role(request, allowed_roles: set, message: str = None):
    """
    Return None if allowed, or a 403 Response if the user's role is not in
    `allowed_roles`.

    Example:
        err = require_role(request, SENIOR_ROLES)
        if err: return err
    """
    if _role(request) not in allowed_roles:
        detail = message or (
            f"Your role ({_role(request) or 'unknown'}) does not have "
            f"permission to perform this action."
        )
        return Response({"detail": detail}, status=status.HTTP_403_FORBIDDEN)
    return None


# ── Permission key → allowed roles (mirrors Flutter rbac.dart _matrix) ────────

_PERMISSION_ROLE_MAP: dict[str, set] = {
    "viewReports": REPORTS_ROLES,
    "manageUsers": SENIOR_ROLES,
    "manageSettings": SENIOR_ROLES,
    "viewNotifications": NOTIFICATIONS_ROLES,
    "viewSubscription": SUBSCRIPTION_ROLES,
    "retailPOS": RETAIL_POS,
    "wholesalePOS": WHOLESALE_POS,
    "viewWholesale": WHOLESALE_POS,
    "readInventory": INVENTORY_READ,
    "writeInventory": INVENTORY_WRITE,
    "readCustomers": ALL_STAFF,
    "writeCustomers": CUSTOMERS_WRITE,
    "manageExpenses": EXPENSES_ROLES,
    "manageSuppliers": SUPPLIERS_ROLES,
    "processPayments": PAYMENTS_ROLES,
    "manageTransfers": TRANSFERS_ROLES,
}


def get_effective_permissions(user) -> dict:
    """
    Return the effective permission dict for a user:
      1. Start from role defaults (from _PERMISSION_ROLE_MAP)
      2. Apply any UserPermissionOverride rows for this user

    Keys match Flutter AppPermission constants.
    """
    role = getattr(user, "role", "") or ""
    defaults = {perm: role in allowed for perm, allowed in _PERMISSION_ROLE_MAP.items()}

    try:
        from authapp.models import UserPermissionOverride

        for ov in UserPermissionOverride.objects.filter(user=user).only(
            "permission", "granted"
        ):
            if ov.permission in defaults:
                defaults[ov.permission] = ov.granted
    except Exception:
        pass

    return defaults
