/// Role-Based Access Control for PharmApp Flutter UI.
///
/// Permission matrix mirrors backend `authapp/permissions.py`.
/// Use [Rbac.can] for imperative checks and [canProvider] in widgets.
library;

import 'package:pharmapp/shared/models/user.dart';

// ── Permission constants ──────────────────────────────────────────────────────

abstract class AppPermission {
  // Reports & Analytics
  static const String viewReports      = 'viewReports';

  // Administration
  static const String manageUsers      = 'manageUsers';
  static const String manageSettings   = 'manageSettings';
  static const String viewNotifications = 'viewNotifications';
  static const String viewSubscription = 'viewSubscription';

  // Finance
  static const String manageExpenses   = 'manageExpenses';
  static const String processPayments  = 'processPayments';

  // Procurement
  static const String manageSuppliers  = 'manageSuppliers';

  // Inventory
  static const String writeInventory   = 'writeInventory';
  static const String readInventory    = 'readInventory';

  // POS
  static const String retailPOS        = 'retailPOS';
  static const String wholesalePOS     = 'wholesalePOS';

  // Customers
  static const String writeCustomers   = 'writeCustomers';
  static const String readCustomers    = 'readCustomers';

  // Wholesale section visibility
  static const String viewWholesale    = 'viewWholesale';

  // Transfers
  static const String manageTransfers  = 'manageTransfers';
}

// ── Role sets (mirrors backend constants) ────────────────────────────────────

const _seniorRoles    = {'Admin', 'Manager'};
const _inventoryWrite = {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'};
const _inventoryRead  = {
  'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech',
  'Salesperson', 'Cashier',
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
const _expensesRoles  = {'Admin', 'Manager', 'Wholesale Manager'};
const _suppliersRoles = {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'};
const _paymentsRoles  = {'Admin', 'Manager', 'Pharmacist', 'Wholesale Manager'};
const _transfersRoles = {'Admin', 'Manager', 'Wholesale Manager', 'Wholesale Operator'};

// ── Permission → allowed role set mapping ────────────────────────────────────

const Map<String, Set<String>> _matrix = {
  AppPermission.viewReports:       _seniorRoles,
  AppPermission.manageUsers:       _seniorRoles,
  AppPermission.manageSettings:    _seniorRoles,
  AppPermission.viewNotifications: _seniorRoles,
  AppPermission.viewSubscription:  _seniorRoles,
  AppPermission.manageExpenses:    _expensesRoles,
  AppPermission.processPayments:   _paymentsRoles,
  AppPermission.manageSuppliers:   _suppliersRoles,
  AppPermission.writeInventory:    _inventoryWrite,
  AppPermission.readInventory:     _inventoryRead,
  AppPermission.retailPOS:         _retailPOS,
  AppPermission.wholesalePOS:      _wholesalePOS,
  AppPermission.viewWholesale:     _wholesalePOS,
  AppPermission.writeCustomers:    _customersWrite,
  AppPermission.readCustomers:     _allStaff,
  AppPermission.manageTransfers:   _transfersRoles,
};

// ── Rbac helper ──────────────────────────────────────────────────────────────

class Rbac {
  const Rbac._();

  /// Returns true if [user]'s role has [permission].
  /// Null user / unknown role → false.
  static bool can(User? user, String permission) {
    if (user == null) return false;
    final role = user.role;
    final allowed = _matrix[permission];
    if (allowed == null) return false;
    return allowed.contains(role);
  }

  /// Convenience: true when role is Admin or Manager.
  static bool isSenior(User? user) => can(user, AppPermission.viewReports);

  /// Convenience: true when user has access to any wholesale feature.
  static bool hasWholesaleAccess(User? user) => can(user, AppPermission.viewWholesale);
}
