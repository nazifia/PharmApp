import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pharmapp/features/auth/screens/login_screen.dart';
import 'package:pharmapp/features/auth/screens/role_selection_screen.dart';
import 'package:pharmapp/features/auth/screens/verify_code_screen.dart';
import 'package:pharmapp/features/auth/screens/setup_screen.dart';
import 'package:pharmapp/features/auth/screens/register_org_screen.dart';
import 'package:pharmapp/features/dashboard/screens/main_dashboard.dart';
import 'package:pharmapp/features/pos/screens/retail_pos_screen.dart';
import 'package:pharmapp/features/pos/screens/wholesale_pos_screen.dart';
import 'package:pharmapp/features/inventory/screens/inventory_list_screen.dart';
import 'package:pharmapp/features/customers/screens/customer_list_screen.dart';
import 'package:pharmapp/features/customers/screens/customer_detail_screen.dart';
import 'package:pharmapp/features/customers/screens/wallet_screen.dart';
import 'package:pharmapp/features/wholesale/screens/wholesale_dashboard_screen.dart';
import 'package:pharmapp/features/wholesale/screens/transfers_screen.dart';
import 'package:pharmapp/features/wholesale/screens/wholesale_sales_screen.dart';
import 'package:pharmapp/features/admin/screens/admin_dashboard.dart';
import 'package:pharmapp/features/reports/screens/reports_hub_screen.dart';
import 'package:pharmapp/features/reports/screens/sales_report_screen.dart';
import 'package:pharmapp/features/reports/screens/inventory_report_screen.dart';
import 'package:pharmapp/features/reports/screens/customer_report_screen.dart';
import 'package:pharmapp/features/reports/screens/profit_report_screen.dart';
import 'package:pharmapp/features/reports/screens/monthly_report_screen.dart';
import 'package:pharmapp/features/reports/screens/cashier_sales_screen.dart';
import 'package:pharmapp/features/settings/screens/app_settings_screen.dart';
import 'package:pharmapp/features/settings/screens/edit_profile_screen.dart';
import 'package:pharmapp/features/inventory/screens/item_detail_screen.dart';
import 'package:pharmapp/features/pos/screens/payment_screen.dart';
import 'package:pharmapp/features/pos/screens/dispensing_log_screen.dart';
import 'package:pharmapp/features/pos/screens/sales_history_screen.dart';
import 'package:pharmapp/features/pos/screens/expenses_screen.dart';
import 'package:pharmapp/features/pos/screens/suppliers_screen.dart';
import 'package:pharmapp/features/pos/screens/stock_check_screen.dart';
import 'package:pharmapp/features/pos/screens/payment_requests_screen.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/models/user.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/features/auth/screens/user_management_screen.dart';
import 'package:pharmapp/features/notifications/screens/notifications_screen.dart';
import 'package:pharmapp/features/subscription/screens/subscription_screen.dart';
import 'package:pharmapp/features/subscription/screens/billing_screen.dart';
import 'package:pharmapp/features/superuser/screens/superuser_dashboard_screen.dart';
import 'package:pharmapp/features/superuser/screens/org_subscription_editor_screen.dart';
import 'package:pharmapp/features/superuser/screens/plan_feature_editor_screen.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import 'package:pharmapp/shared/widgets/sync_queue_screen.dart';
import 'package:pharmapp/features/branches/screens/branch_management_screen.dart';
import 'package:pharmapp/features/branches/screens/branch_selection_screen.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/features/auth/screens/activity_log_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _GoRouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState       = ref.read(authFlowProvider);
      final token           = ref.read(authTokenProvider);
      // Treat session as unauthenticated if the interceptor wiped the token
      // (e.g. 401 on subscription fetch) but authFlowProvider wasn't reset.
      final isAuthenticated = authState == AuthFlowState.authenticated && token != null;
      final loc             = state.matchedLocation;
      final user            = ref.read(currentUserProvider);

      // Returns true when the user must pick a branch before continuing.
      // Only applies to multi-branch subscribers whose account has no
      // backend-assigned branch (branchId == 0 means org-wide access that
      // needs an explicit selection each session).
      bool needsBranchSelection() =>
          user != null &&
          user.organizationId != 0 &&
          user.branchId == 0 &&
          ref.read(hasFeatureProvider(SaasFeature.multiBranch)) &&
          ref.read(activeBranchProvider) == null;

      const publicRoutes = ['/login', '/role-selection', '/setup', '/register-org'];

      if (publicRoutes.contains(loc)) {
        if (isAuthenticated) {
          if (needsBranchSelection()) return '/select-branch';
          return _getRoleRoute(user?.role);
        }
        return null;
      }

      if (!isAuthenticated) return '/login';

      // Already selected a branch (or skipped) — leave /select-branch
      if (loc == '/select-branch' && !needsBranchSelection()) {
        return _getRoleRoute(user?.role);
      }

      // Force branch selection before any protected screen
      if (loc != '/select-branch' && needsBranchSelection()) {
        return '/select-branch';
      }

      // Reports — Admin / Manager only (cashier-sales is self-service for all)
      if (loc.startsWith('/dashboard/reports') &&
          loc != '/dashboard/reports/cashier-sales' &&
          !Rbac.can(user, AppPermission.viewReports)) {
        return '/dashboard';
      }

      // User management — Admin / Manager only
      if (loc == '/dashboard/users' && !Rbac.can(user, AppPermission.manageUsers)) {
        return '/dashboard';
      }

      // Activity log — Admin / Manager only
      if (loc == '/dashboard/activity-log' && !Rbac.can(user, AppPermission.viewActivityLog)) {
        return '/dashboard';
      }

      // Settings screen is open to all roles; admin-only sections gated in-screen.

      // Notifications — Admin / Manager only
      if (loc == '/dashboard/notifications' && !Rbac.can(user, AppPermission.viewNotifications)) {
        return '/dashboard';
      }

      // Expenses — Admin / Manager / Wholesale Manager
      if (loc == '/dashboard/expenses' && !Rbac.can(user, AppPermission.manageExpenses)) {
        return '/dashboard';
      }

      // Suppliers — Admin / Manager / Pharmacist / Wholesale Manager
      if (loc == '/dashboard/suppliers' && !Rbac.can(user, AppPermission.manageSuppliers)) {
        return '/dashboard';
      }

      // Transfers — Admin / Manager / Wholesale Manager / Wholesale Operator
      if (loc == '/dashboard/transfers' && !Rbac.can(user, AppPermission.manageTransfers)) {
        return '/dashboard';
      }

      // Wholesale POS — wholesale roles only
      if (loc == '/dashboard/wholesale-pos' && !Rbac.can(user, AppPermission.wholesalePOS)) {
        return '/dashboard';
      }

      // Wholesale sales / dashboard — wholesale roles only
      if ((loc == '/dashboard/wholesale-sales' || loc == '/wholesale-dashboard') &&
          !Rbac.can(user, AppPermission.viewWholesale)) {
        return '/dashboard';
      }

      // Inventory — readInventory required (Cashiers are excluded)
      if ((loc == '/dashboard/inventory' || loc.startsWith('/item/')) &&
          !Rbac.can(user, AppPermission.readInventory)) {
        return '/dashboard';
      }

      // Payment requests — processPayments required
      if (loc == '/dashboard/payment-requests' &&
          !Rbac.can(user, AppPermission.processPayments)) {
        return '/dashboard';
      }

      // ── Superuser gate ────────────────────────────────────────────────────
      if ((loc == '/superuser' || loc.startsWith('/superuser/')) &&
          !Rbac.isSuperuser(user)) {
        return '/dashboard';
      }

      // ── Subscription feature gates (redirect to paywall) ──────────────────

      // Catch-all: expired / suspended / cancelled subscriptions lose access
      // to all protected routes. isAccessible covers active, trial, and expiring.
      if (!ref.read(subscriptionAccessibleProvider) &&
          loc != '/subscription' && loc != '/billing') {
        return '/subscription';
      }

      // Customers — Starter plan and above
      if ((loc.startsWith('/dashboard/customers') || loc.startsWith('/customer/')) &&
          !ref.read(hasFeatureProvider(SaasFeature.customers))) {
        return '/subscription';
      }

      // Reports — Starter plan and above (cashier-sales is always accessible)
      if (loc.startsWith('/dashboard/reports') &&
          loc != '/dashboard/reports/cashier-sales' &&
          !ref.read(hasFeatureProvider(SaasFeature.basicReports))) {
        return '/subscription';
      }

      // Advanced reports (profit + monthly) — Professional plan and above
      if ((loc == '/dashboard/reports/profit' || loc == '/dashboard/reports/monthly') &&
          !ref.read(hasFeatureProvider(SaasFeature.advancedReports))) {
        return '/subscription';
      }

      // User management — Starter plan and above
      if (loc == '/dashboard/users' &&
          !ref.read(hasFeatureProvider(SaasFeature.userManagement))) {
        return '/subscription';
      }

      // Wholesale — Professional plan and above
      if ((loc.contains('wholesale') || loc == '/wholesale-dashboard') &&
          !ref.read(hasFeatureProvider(SaasFeature.wholesale))) {
        return '/subscription';
      }

      // Multi-branch — Professional / Enterprise only
      if (loc == '/dashboard/branches' &&
          !ref.read(hasFeatureProvider(SaasFeature.multiBranch))) {
        return '/subscription';
      }

      return null;
    },
    routes: [
      // ── Public ─────────────────────────────────────────────────────────────
      GoRoute(path: '/login',          name: 'login',        builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/verify-code',    name: 'verify_code',  builder: (_, __) => const VerifyCodeScreen()),
      GoRoute(path: '/role-selection', name: 'role_select',  builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: '/setup',          name: 'setup',        builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/register-org',   name: 'register_org',  builder: (_, __) => const RegisterOrgScreen()),
      GoRoute(path: '/select-branch',  name: 'select_branch', builder: (_, __) => const BranchSelectionScreen()),
      GoRoute(path: '/subscription',   name: 'subscription',  builder: (_, __) => const SubscriptionScreen()),
      GoRoute(path: '/billing',        name: 'billing',       builder: (_, __) => const BillingScreen()),
      GoRoute(path: '/superuser',        name: 'superuser',       builder: (_, __) => const SuperuserDashboardScreen()),
      GoRoute(path: '/superuser/plans',  name: 'superuser_plans', builder: (_, __) => const PlanFeatureEditorScreen()),
      GoRoute(
        path: '/superuser/org/:id',
        name: 'superuser_org',
        builder: (_, state) => OrgSubscriptionEditorScreen(
          orgId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // ── Authenticated shell (persistent bottom nav bar) ────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [

          // ── Main dashboard (retail) ───────────────────────────────────────
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const MainDashboard(),
            routes: [
              GoRoute(path: 'pos',             name: 'retail_pos',      builder: (_, __) => const RetailPOSScreen()),
              GoRoute(path: 'wholesale-pos',   name: 'wholesale_pos',   builder: (_, __) => const WholesalePOSScreen()),
              GoRoute(path: 'inventory',       name: 'inventory',       builder: (_, __) => const InventoryListScreen()),
              GoRoute(path: 'customers',       name: 'customers',       builder: (_, __) => const CustomerListScreen()),
              GoRoute(path: 'reports',         name: 'reports_hub',     builder: (_, __) => const ReportsHubScreen()),
              GoRoute(path: 'reports/sales',   name: 'sales_report',    builder: (_, __) => const SalesReportScreen()),
              GoRoute(path: 'reports/inventory',name: 'inventory_report',builder: (_, __) => const InventoryReportScreen()),
              GoRoute(path: 'reports/customers',name: 'customer_report', builder: (_, __) => const CustomerReportScreen()),
              GoRoute(path: 'reports/profit',  name: 'profit_report',   builder: (_, __) => const ProfitReportScreen()),
              GoRoute(path: 'reports/monthly',       name: 'monthly_report',        builder: (_, __) => const MonthlyReportScreen()),
              GoRoute(path: 'reports/cashier-sales', name: 'cashier_sales_report',  builder: (_, __) => const CashierSalesScreen()),
              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (_, __) => const AppSettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'edit-profile',
                    name: 'edit_profile',
                    builder: (_, __) => const EditProfileScreen(),
                  ),
                ],
              ),
              GoRoute(path: 'users',           name: 'users',           builder: (_, __) => const UserManagementScreen()),
              GoRoute(path: 'notifications',   name: 'notifications',   builder: (_, __) => const NotificationsScreen()),
              GoRoute(path: 'dispensing-log',  name: 'dispensing_log',  builder: (_, __) => const DispensingLogScreen()),
              GoRoute(path: 'sales',           name: 'sales_history',   builder: (_, __) => const SalesHistoryScreen()),
              GoRoute(path: 'expenses',        name: 'expenses',        builder: (_, __) => const ExpensesScreen()),
              GoRoute(path: 'suppliers',       name: 'suppliers',       builder: (_, __) => const SuppliersScreen()),
              GoRoute(path: 'stock-check',          name: 'stock_check',          builder: (_, __) => const StockCheckScreen()),
              GoRoute(path: 'ws-stock-check',       name: 'ws_stock_check',       builder: (_, __) => const StockCheckScreen(isWholesale: true)),
              GoRoute(path: 'stock-check-report',   name: 'stock_check_report',   builder: (_, __) => const StockCheckScreen(showReport: true)),
              GoRoute(path: 'ws-stock-check-report',name: 'ws_stock_check_report',builder: (_, __) => const StockCheckScreen(isWholesale: true, showReport: true)),
              GoRoute(path: 'payment-requests',name: 'payment_requests',builder: (_, __) => const PaymentRequestsScreen()),
              GoRoute(path: 'transfers',       name: 'transfers',       builder: (_, __) => const TransfersScreen()),
              GoRoute(path: 'wholesale-sales', name: 'wholesale_sales', builder: (_, __) => const WholesaleSalesScreen()),
              GoRoute(path: 'sync-queue',      name: 'sync_queue',      builder: (_, __) => const SyncQueueScreen()),
              GoRoute(path: 'branches',        name: 'branches',        builder: (_, __) => const BranchManagementScreen()),
              GoRoute(path: 'activity-log',    name: 'activity_log',    builder: (_, __) => const ActivityLogScreen()),
            ],
          ),

          // ── Admin ─────────────────────────────────────────────────────────
          GoRoute(
            path: '/admin-dashboard',
            name: 'admin_dashboard',
            builder: (_, __) => const AdminDashboard(),
            routes: [
              GoRoute(path: 'reports',  name: 'admin_reports',  builder: (_, __) => const SalesReportScreen()),
              GoRoute(path: 'settings', name: 'admin_settings', builder: (_, __) => const AppSettingsScreen()),
            ],
          ),

          // ── Wholesale ──────────────────────────────────────────────────────
          GoRoute(path: '/wholesale-dashboard', name: 'wholesale_dashboard', builder: (_, __) => const WholesaleDashboardScreen()),

          // ── Item / Customer detail (inside shell so back nav works) ────────
          GoRoute(path: '/item/:id',            name: 'item_details',    builder: (_, __) => const ItemDetailScreen()),
          GoRoute(path: '/customer/:id',        name: 'customer_detail', builder: (_, __) => const CustomerDetailScreen()),
          GoRoute(path: '/customer/:id/wallet', name: 'customer_wallet', builder: (_, __) => const WalletScreen()),
          GoRoute(path: '/payment',             name: 'payment',         builder: (_, __) => const PaymentScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error?.toString()),
  );
});

String _getRoleRoute(String? role) {
  switch (role) {
    case 'Admin':
    case 'Manager':
      return '/admin-dashboard';
    case 'Wholesale Manager':
    case 'Wholesale Operator':
    case 'Wholesale Salesperson':
      return '/wholesale-dashboard';
    default:
      return '/dashboard';
  }
}

class _GoRouterNotifier extends ChangeNotifier {
  _GoRouterNotifier(Ref ref) {
    ref.listen<AuthFlowState>(authFlowProvider, (_, __) => notifyListeners());
    // Re-evaluate when the token is cleared (e.g. 401 interceptor wipes it)
    // so the router redirects to /login even if authFlowProvider wasn't reset.
    ref.listen<String?>(authTokenProvider, (_, __) => notifyListeners());
    // Re-evaluate redirect when branch selection changes.
    ref.listen(activeBranchProvider, (_, __) => notifyListeners());
    // Re-evaluate when user profile refreshes (e.g. branchId assigned by admin,
    // permission overrides applied) so the router reacts without waiting for
    // activeBranchProvider to change independently.
    ref.listen<User?>(currentUserProvider, (_, __) => notifyListeners());
  }
}

// ── Error screen ──────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String? error;
  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.15)),
                ),
                child: const Icon(Icons.error_outline, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Something went wrong',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'An unexpected error occurred.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
