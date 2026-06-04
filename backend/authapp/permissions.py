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

from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import BasePermission
from rest_framework.response import Response
from rest_framework import status

# Paths exempt from subscription enforcement.
# Auth and subscription endpoints must remain reachable even when suspended.
_SUBSCRIPTION_EXEMPT_PREFIXES = (
    '/api/auth/',
    '/api/subscription/',
    '/admin/',
)

# Subscription statuses that block all data API access.
_BLOCKED_STATUSES = {'suspended', 'cancelled', 'expired'}

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
PRESCRIPTIONS_WRITE = {"Admin", "Manager", "Pharmacist", "Pharm-Tech"}
PRESCRIPTIONS_READ  = {"Admin", "Manager", "Pharmacist", "Pharm-Tech", "Salesperson", "Cashier"}
EXPENSES_ROLES = {"Admin", "Manager", "Wholesale Manager"}
SUPPLIERS_ROLES = {"Admin", "Manager", "Pharmacist", "Wholesale Manager"}
PAYMENTS_ROLES = {"Admin", "Manager", "Pharmacist", "Wholesale Manager"}
REPORTS_ROLES = SENIOR_ROLES | {"Wholesale Manager"}
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
LOW_STOCK_ALERT_ROLES = SENIOR_ROLES

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
    ("Create Inventory", "createInventory"),
    ("Write Inventory", "writeInventory"),
    ("Read Customers", "readCustomers"),
    ("Write Customers", "writeCustomers"),
    ("View Prescriptions", "readPrescriptions"),
    ("Write Prescriptions", "writePrescriptions"),
    ("Manage Expenses", "manageExpenses"),
    ("Manage Suppliers", "manageSuppliers"),
    ("Process Payments", "processPayments"),
    ("Manage Transfers", "manageTransfers"),
    ("Edit Low Stock Alert", "editLowStockAlert"),
]


# ── DRF Permission classes ─────────────────────────────────────────────────────


class OrgSubscriptionPermission(BasePermission):
    """
    Blocks all data API calls when the org's subscription is suspended,
    cancelled, or expired.

    Exempt paths (auth + subscription endpoints) are always allowed so that:
    - Users can still log in / out.
    - The Flutter app can fetch the current subscription status to show the
      correct blocked-state UI in SubscriptionScreen.

    Superusers bypass this check entirely (they can manage any org).

    How it integrates with the Flutter app:
    - Suspended/cancelled/expired → 403 with {"code": "org_suspended" | "org_cancelled" | "org_expired"}
    - Flutter AuthInterceptor increments orgAccessRevokedProvider on 403
    - SubscriptionNotifier refreshes → subscriptionAccessibleProvider = false
    - Router guard redirects to /subscription → user sees blocked-state banner
    """

    def has_permission(self, request, view):
        user = request.user

        # Anonymous requests — let IsAuthenticated handle this.
        if not user or not user.is_authenticated:
            return True

        # Superusers are never blocked.
        if user.is_superuser:
            return True

        # Exempt auth and subscription endpoints.
        path = request.path
        if any(path.startswith(prefix) for prefix in _SUBSCRIPTION_EXEMPT_PREFIXES):
            return True

        # Check org subscription status.
        org = getattr(user, 'organization', None)
        if org is None:
            return True  # no org → other checks handle this

        try:
            sub = org.subscription
        except Exception:
            return True  # no subscription record → allow (trial not yet created)

        if sub.status in _BLOCKED_STATUSES:
            _status_map = {
                'suspended': ('org_suspended',  'Organization subscription is suspended.'),
                'cancelled': ('org_cancelled',  'Organization subscription has been cancelled.'),
                'expired':   ('org_expired',    'Organization subscription has expired.'),
            }
            code, detail = _status_map.get(sub.status, ('org_blocked', 'Organization access blocked.'))
            # Raise PermissionDenied directly so the response body includes `code`
            # alongside `detail`, giving the Flutter app a machine-readable signal.
            raise PermissionDenied({'detail': detail, 'code': code})

        return True


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


class IsReportsUser(BasePermission):
    message = "You do not have permission to access reports."

    def has_permission(self, request, view):
        user = request.user
        if getattr(user, 'is_superuser', False):
            return True
        return get_effective_permissions(user).get("viewReports", False)


class IsRetailStaff(BasePermission):
    message = "You do not have access to the retail POS module."

    def has_permission(self, request, view):
        user = request.user
        if getattr(user, 'is_superuser', False):
            return True
        return get_effective_permissions(user).get("retailPOS", False)


class IsWholesaleStaff(BasePermission):
    message = "You do not have access to the wholesale POS module."

    def has_permission(self, request, view):
        user = request.user
        if getattr(user, 'is_superuser', False):
            return True
        return get_effective_permissions(user).get("wholesalePOS", False)


class IsInventoryEditor(BasePermission):
    """
    Read (GET/HEAD/OPTIONS): requires readInventory effective permission.
    Write (POST/PUT/PATCH/DELETE): requires writeInventory effective permission.
    Individual overrides take precedence over role defaults.
    """

    message = "Your role cannot modify inventory."

    def has_permission(self, request, view):
        user = request.user
        if getattr(user, 'is_superuser', False):
            return True
        perms = get_effective_permissions(user)
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return perms.get("readInventory", False)
        if request.method == "POST":
            return perms.get("createInventory", False) or perms.get("writeInventory", False)
        return perms.get("writeInventory", False)


class IsCustomerEditor(BasePermission):
    """
    Read: requires readCustomers effective permission.
    Write: requires writeCustomers effective permission.
    Individual overrides take precedence over role defaults.
    """

    message = "Your role cannot modify customer records."

    def has_permission(self, request, view):
        user = request.user
        if getattr(user, 'is_superuser', False):
            return True
        perms = get_effective_permissions(user)
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return perms.get("readCustomers", False)
        return perms.get("writeCustomers", False)


class IsPrescriptionUser(BasePermission):
    """
    Read (GET/HEAD/OPTIONS): requires readPrescriptions effective permission.
    Write (POST/PUT/PATCH/DELETE): requires writePrescriptions effective permission.
    """

    message = "You do not have permission to access prescriptions."

    def has_permission(self, request, view):
        user = request.user
        if getattr(user, 'is_superuser', False):
            return True
        perms = get_effective_permissions(user)
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return perms.get("readPrescriptions", False)
        return perms.get("writePrescriptions", False)


# ── Effective-permission factory ───────────────────────────────────────────────


def HasEffectivePermission(perm_key: str) -> type:
    """
    Returns a DRF permission class that checks a single effective permission
    (role default merged with individual UserPermissionOverride records).

    Usage:
        @permission_classes([IsAuthenticated, HasEffectivePermission('viewReports')])
        def my_view(request): ...
    """
    class _HasEffPerm(BasePermission):
        message = f"You do not have the '{perm_key}' permission."

        def has_permission(self, request, view):
            user = request.user
            if not user or not user.is_authenticated:
                return False
            if getattr(user, 'is_superuser', False):
                return True
            perms = get_effective_permissions(user)
            return perms.get(perm_key, False)

    _HasEffPerm.__name__ = f"HasPerm_{perm_key}"
    _HasEffPerm.__qualname__ = f"HasPerm_{perm_key}"
    return _HasEffPerm


# ── Functional helpers (use when you need an inline check) ────────────────────


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


def require_permission(request, perm_key: str, message: str = None):
    """
    Return None if the user's effective permission for `perm_key` is True,
    or a 403 Response otherwise.  Honors individual UserPermissionOverride records.

    Example:
        err = require_permission(request, 'manageTransfers')
        if err: return err
    """
    user = request.user
    if getattr(user, 'is_superuser', False):
        return None
    perms = get_effective_permissions(user)
    if not perms.get(perm_key, False):
        detail = message or f"You do not have the '{perm_key}' permission."
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
    "createInventory": INVENTORY_WRITE,
    "writeInventory": INVENTORY_WRITE,
    "readCustomers":      ALL_STAFF,
    "writeCustomers":     CUSTOMERS_WRITE,
    "readPrescriptions":  PRESCRIPTIONS_READ,
    "writePrescriptions": PRESCRIPTIONS_WRITE,
    "manageExpenses":     EXPENSES_ROLES,
    "manageSuppliers": SUPPLIERS_ROLES,
    "processPayments": PAYMENTS_ROLES,
    "manageTransfers": TRANSFERS_ROLES,
    "editLowStockAlert": LOW_STOCK_ALERT_ROLES,
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
