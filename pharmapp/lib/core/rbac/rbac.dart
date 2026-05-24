/// Role-Based Access Control for PharmApp Flutter UI.
///
/// Permission matrix mirrors backend `authapp/permissions.py`.
/// Use [Rbac.can] for imperative checks and [canProvider] in widgets.
library;

import 'package:pharmapp/shared/models/user.dart';

// ── Permission constants ──────────────────────────────────────────────────────

abstract class AppPermission {
  // Platform superuser
  static const String platformAdmin    = 'platformAdmin';

  // Reports & Analytics
  static const String viewReports      = 'viewReports';

  // Administration
  static const String manageUsers      = 'manageUsers';
  static const String manageSettings   = 'manageSettings';
  static const String viewNotifications = 'viewNotifications';
  static const String viewSubscription = 'viewSubscription';
  static const String viewActivityLog  = 'viewActivityLog';

  // Finance
  static const String manageExpenses   = 'manageExpenses';
  static const String processPayments  = 'processPayments';

  // Procurement
  static const String manageSuppliers  = 'manageSuppliers';

  // Inventory
  static const String createInventory  = 'createInventory';
  static const String writeInventory   = 'writeInventory';
  static const String readInventory    = 'readInventory';
  static const String adjustStock      = 'adjust_stock';

  // POS
  static const String retailPOS        = 'retailPOS';
  static const String wholesalePOS     = 'wholesalePOS';

  // Customers
  static const String writeCustomers   = 'writeCustomers';
  static const String readCustomers    = 'readCustomers';

  // Prescriptions
  static const String writePrescriptions = 'writePrescriptions';
  static const String readPrescriptions  = 'readPrescriptions';

  // Wholesale section visibility
  static const String viewWholesale    = 'viewWholesale';

  // Finance visibility
  static const String viewCostPrice    = 'viewCostPrice';

  // Transfers
  static const String manageTransfers  = 'manageTransfers';
}

// ── Role sets (mirrors backend constants) ────────────────────────────────────

const _seniorRoles    = {'Admin', 'Manager'};
const _inventoryWrite = {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'};
const _inventoryRead  = {
  'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech',
  'Salesperson',
  'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson',
};
const _retailPOS = {
  'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Salesperson', 'Cashier',
};
const _wholesalePOS = {
  'Admin', 'Manager', 'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson',
};
const _allStaff = {
  'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Salesperson', 'Cashier',
  'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson',
};
const _customersWrite = {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Wholesale Manager'};
const _prescriptionsWrite = {'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech'};
const _prescriptionsRead  = {
  'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech', 'Salesperson', 'Cashier',
};
const _costPriceRoles = {'Admin', 'Manager'};
const _expensesRoles  = {'Admin', 'Manager', 'Wholesale Manager'};
const _suppliersRoles = {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'};
const _paymentsRoles  = {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager', 'Cashier'};
const _transfersRoles = {'Admin', 'Manager', 'Wholesale Manager', 'Wholesale Operator'};

// ── Permission → allowed role set mapping ────────────────────────────────────

// Superuser is handled separately via User.isSuperuser — not a role.
const Map<String, Set<String>> _matrix = {
  AppPermission.viewReports:       _seniorRoles,
  AppPermission.manageUsers:       _seniorRoles,
  AppPermission.manageSettings:    _seniorRoles,
  AppPermission.viewNotifications: _seniorRoles,
  AppPermission.viewSubscription:  _seniorRoles,
  AppPermission.viewActivityLog:   _seniorRoles,
  AppPermission.manageExpenses:    _expensesRoles,
  AppPermission.processPayments:   _paymentsRoles,
  AppPermission.manageSuppliers:   _suppliersRoles,
  AppPermission.createInventory:   _inventoryWrite,
  AppPermission.writeInventory:    _inventoryWrite,
  AppPermission.readInventory:     _inventoryRead,
  AppPermission.adjustStock:       _seniorRoles,
  AppPermission.retailPOS:         _retailPOS,
  AppPermission.wholesalePOS:      _wholesalePOS,
  AppPermission.viewWholesale:     _wholesalePOS,
  AppPermission.writeCustomers:      _customersWrite,
  AppPermission.readCustomers:       _allStaff,
  AppPermission.viewCostPrice:       _costPriceRoles,
  AppPermission.manageTransfers:     _transfersRoles,
  AppPermission.writePrescriptions:  _prescriptionsWrite,
  AppPermission.readPrescriptions:   _prescriptionsRead,
};

// ── Rbac helper ──────────────────────────────────────────────────────────────

// ── Ordered list of all permissions (used for local permission sheet) ────────

const List<String> allPermissions = [
  AppPermission.viewReports,
  AppPermission.manageUsers,
  AppPermission.manageSettings,
  AppPermission.viewNotifications,
  AppPermission.viewSubscription,
  AppPermission.viewActivityLog,
  AppPermission.manageExpenses,
  AppPermission.processPayments,
  AppPermission.manageSuppliers,
  AppPermission.createInventory,
  AppPermission.writeInventory,
  AppPermission.readInventory,
  AppPermission.adjustStock,
  AppPermission.retailPOS,
  AppPermission.wholesalePOS,
  AppPermission.writeCustomers,
  AppPermission.readCustomers,
  AppPermission.viewWholesale,
  AppPermission.viewCostPrice,
  AppPermission.manageTransfers,
  AppPermission.writePrescriptions,
  AppPermission.readPrescriptions,
];

// ── Human-readable labels for each permission ────────────────────────────────

const Map<String, String> permissionLabels = {
  AppPermission.platformAdmin:     'Platform Admin',
  AppPermission.viewReports:       'View Reports',
  AppPermission.manageUsers:       'Manage Users',
  AppPermission.manageSettings:    'Manage Settings',
  AppPermission.viewNotifications: 'View Notifications',
  AppPermission.viewSubscription:  'View Subscription',
  AppPermission.viewActivityLog:   'View Activity Log',
  AppPermission.manageExpenses:    'Manage Expenses',
  AppPermission.processPayments:   'Process Payments',
  AppPermission.manageSuppliers:   'Manage Suppliers',
  AppPermission.createInventory:   'Create Inventory',
  AppPermission.writeInventory:    'Edit Inventory',
  AppPermission.readInventory:     'View Inventory',
  AppPermission.adjustStock:       'Adjust Stock',
  AppPermission.retailPOS:         'Retail POS',
  AppPermission.wholesalePOS:      'Wholesale POS',
  AppPermission.writeCustomers:      'Edit Customers',
  AppPermission.readCustomers:       'View Customers',
  AppPermission.viewWholesale:       'Wholesale Access',
  AppPermission.viewCostPrice:       'View Cost Price',
  AppPermission.manageTransfers:     'Manage Transfers',
  AppPermission.writePrescriptions:  'Write Prescriptions',
  AppPermission.readPrescriptions:   'View Prescriptions',
};

class Rbac {
  const Rbac._();

  /// Returns true if [user] has [permission].
  /// Individual overrides from [user.permissions] take precedence over role defaults.
  /// Null user / unknown role → false.
  static bool can(User? user, String permission) {
    if (user == null) return false;

    // Individual override takes precedence over role default
    if (user.permissions.containsKey(permission)) {
      return user.permissions[permission]!;
    }

    // Fall back to role-based matrix
    final role = user.role;
    final allowed = _matrix[permission];
    if (allowed == null) return false;
    return allowed.contains(role);
  }

  /// Returns the role-matrix default for [permission] (ignoring individual overrides).
  static bool roleDefault(User? user, String permission) {
    if (user == null) return false;
    return roleDefaultForRole(user.role, permission);
  }

  /// Returns the role-matrix default for [role] string (no User object needed).
  static bool roleDefaultForRole(String role, String permission) {
    final allowed = _matrix[permission];
    if (allowed == null) return false;
    return allowed.contains(role);
  }

  /// Returns true if the user has any individual permission overrides set.
  static bool hasOverrides(User? user) => user != null && user.permissions.isNotEmpty;

  /// Returns the count of permissions explicitly overridden (granted or revoked)
  /// relative to role defaults.
  static int overrideCount(User? user) {
    if (user == null || user.permissions.isEmpty) return 0;
    int count = 0;
    for (final entry in user.permissions.entries) {
      final matrixDefault = roleDefault(user, entry.key);
      if (entry.value != matrixDefault) count++;
    }
    return count;
  }

  /// Convenience: true when role is Admin or Manager.
  static bool isSenior(User? user) => can(user, AppPermission.viewReports);

  /// True when user may view Inventory/Stock screens.
  /// Admin/Manager always can; other roles only when explicitly granted via
  /// a personal permission override (user.permissions[readInventory] == true).
  static bool canViewInventory(User? user) {
    if (user == null) return false;
    if (isSenior(user)) return true;
    return user.permissions[AppPermission.readInventory] == true;
  }

  /// Convenience: true when user has access to any wholesale feature.
  static bool hasWholesaleAccess(User? user) => can(user, AppPermission.viewWholesale);

  /// True for platform-level superusers (cross-org subscription management).
  /// Bypasses all role-based checks — only set by the backend via isSuperuser.
  static bool isSuperuser(User? user) => user?.isSuperuser == true;
}
