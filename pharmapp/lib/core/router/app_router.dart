import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pharmapp/features/auth/screens/login_screen.dart';
import 'package:pharmapp/features/auth/screens/role_selection_screen.dart';
import 'package:pharmapp/features/auth/screens/verify_code_screen.dart';
import 'package:pharmapp/features/auth/screens/setup_screen.dart';
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
import 'package:pharmapp/features/settings/screens/app_settings_screen.dart';
import 'package:pharmapp/features/inventory/screens/item_detail_screen.dart';
import 'package:pharmapp/features/pos/screens/payment_screen.dart';
import 'package:pharmapp/features/pos/screens/dispensing_log_screen.dart';
import 'package:pharmapp/features/pos/screens/sales_history_screen.dart';
import 'package:pharmapp/features/pos/screens/expenses_screen.dart';
import 'package:pharmapp/features/pos/screens/suppliers_screen.dart';
import 'package:pharmapp/features/pos/screens/stock_check_screen.dart';
import 'package:pharmapp/features/pos/screens/payment_requests_screen.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/auth/screens/user_management_screen.dart';
import 'package:pharmapp/features/notifications/screens/notifications_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _GoRouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState     = ref.read(authFlowProvider);
      final isAuthenticated = authState == AuthFlowState.authenticated;
      final loc = state.matchedLocation;

      const publicRoutes = ['/login', '/role-selection', '/setup'];

      if (publicRoutes.contains(loc)) {
        if (isAuthenticated) {
          final user = ref.read(currentUserProvider);
          return _getRoleRoute(user?.role);
        }
        return null;
      }

      if (!isAuthenticated) return '/login';
      return null;
    },
    routes: [
      // ── Public ─────────────────────────────────────────────────────────────
      GoRoute(path: '/login',          name: 'login',        builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/verify-code',    name: 'verify_code',  builder: (_, __) => const VerifyCodeScreen()),
      GoRoute(path: '/role-selection', name: 'role_select',  builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: '/setup',          name: 'setup',        builder: (_, __) => const SetupScreen()),

      // ── Main dashboard (retail) ─────────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (_, __) => const MainDashboard(),
        routes: [
          GoRoute(path: 'pos',            name: 'retail_pos',     builder: (_, __) => const RetailPOSScreen()),
          GoRoute(path: 'wholesale-pos',  name: 'wholesale_pos',  builder: (_, __) => const WholesalePOSScreen()),
          GoRoute(path: 'inventory',      name: 'inventory',      builder: (_, __) => const InventoryListScreen()),
          GoRoute(path: 'customers',      name: 'customers',      builder: (_, __) => const CustomerListScreen()),
          GoRoute(path: 'reports',           name: 'reports_hub',      builder: (_, __) => const ReportsHubScreen()),
          GoRoute(path: 'reports/sales',     name: 'sales_report',     builder: (_, __) => const SalesReportScreen()),
          GoRoute(path: 'reports/inventory', name: 'inventory_report', builder: (_, __) => const InventoryReportScreen()),
          GoRoute(path: 'reports/customers', name: 'customer_report',  builder: (_, __) => const CustomerReportScreen()),
          GoRoute(path: 'reports/profit',    name: 'profit_report',    builder: (_, __) => const ProfitReportScreen()),
          GoRoute(path: 'settings',          name: 'settings',         builder: (_, __) => const AppSettingsScreen()),
          GoRoute(path: 'users',           name: 'users',            builder: (_, __) => const UserManagementScreen()),
          GoRoute(path: 'notifications',   name: 'notifications',    builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: 'dispensing-log',  name: 'dispensing_log',   builder: (_, __) => const DispensingLogScreen()),
          GoRoute(path: 'sales',           name: 'sales_history',    builder: (_, __) => const SalesHistoryScreen()),
          GoRoute(path: 'expenses',        name: 'expenses',         builder: (_, __) => const ExpensesScreen()),
          GoRoute(path: 'suppliers',       name: 'suppliers',        builder: (_, __) => const SuppliersScreen()),
          GoRoute(path: 'stock-check',     name: 'stock_check',      builder: (_, __) => const StockCheckScreen()),
          GoRoute(path: 'payment-requests',name: 'payment_requests', builder: (_, __) => const PaymentRequestsScreen()),
          GoRoute(path: 'transfers',       name: 'transfers',        builder: (_, __) => const TransfersScreen()),
          GoRoute(path: 'wholesale-sales', name: 'wholesale_sales',  builder: (_, __) => const WholesaleSalesScreen()),
        ],
      ),

      // ── Item / Customer detail ──────────────────────────────────────────────
      GoRoute(path: '/item/:id',              name: 'item_details',    builder: (_, __) => const ItemDetailScreen()),
      GoRoute(path: '/customer/:id',          name: 'customer_detail', builder: (_, __) => const CustomerDetailScreen()),
      GoRoute(path: '/customer/:id/wallet',   name: 'customer_wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/payment',               name: 'payment',         builder: (_, __) => const PaymentScreen()),

      // ── Admin ───────────────────────────────────────────────────────────────
      GoRoute(
        path: '/admin-dashboard',
        name: 'admin_dashboard',
        builder: (_, __) => const AdminDashboard(),
        routes: [
          GoRoute(path: 'reports',  name: 'admin_reports',  builder: (_, __) => const SalesReportScreen()),
          GoRoute(path: 'settings', name: 'admin_settings', builder: (_, __) => const AppSettingsScreen()),
        ],
      ),

      // ── Wholesale ───────────────────────────────────────────────────────────
      GoRoute(path: '/wholesale-dashboard', name: 'wholesale_dashboard', builder: (_, __) => const WholesaleDashboardScreen()),
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
              Text(
                error ?? 'An unexpected error occurred',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
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
