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
import 'package:pharmapp/features/wholesale/screens/wholesale_dashboard.dart';
import 'package:pharmapp/features/admin/screens/admin_dashboard.dart';
import 'package:pharmapp/features/reports/screens/sales_report_screen.dart';
import 'package:pharmapp/features/settings/screens/app_settings_screen.dart';
import 'package:pharmapp/features/inventory/screens/item_detail_screen.dart';
import 'package:pharmapp/features/pos/screens/payment_screen.dart';
import 'package:pharmapp/features/reports/screens/inventory_report_screen.dart';
import 'package:pharmapp/features/reports/screens/customer_report_screen.dart';
import 'package:pharmapp/features/reports/screens/profit_report_screen.dart';
import 'package:pharmapp/core/router/guards/auth_guard.dart';
import 'package:pharmapp/core/router/guards/role_guard.dart';
import 'package:pharmapp/core/router/guards/permission_guard.dart';
import 'package:pharmapp/core/services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _GoRouterNotifier(ref),
    redirect: (context, state) {
      final authService = context.read(authServiceProvider);
      final isAuth = authService.isAuthenticated;
      final currentUser = authService.currentUser;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }

      if (isAuth && isLoggingIn) {
        // Redirect to role selection if user hasn't selected role yet
        if (currentUser?.role == null || currentUser!.role.isEmpty) {
          return '/role-selection';
        }

        // Redirect to appropriate dashboard based on role
        switch (currentUser!.role) {
          case 'Admin':
            return '/admin-dashboard';
          case 'Pharmacist':
            return '/dashboard';
          case 'Cashier':
            return '/dashboard';
          case 'Wholesaler':
            return '/wholesale-dashboard';
          default:
            return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      // Authentication routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
        name: 'login',
      ),
      GoRoute(
        path: '/verify-code',
        builder: (context, state) => const VerifyCodeScreen(),
        name: 'verify_code',
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
        name: 'role_selection',
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
        name: 'setup',
      ),

      // Public routes
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
        name: 'home',
      ),

      // Authenticated routes with role-based access
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainDashboard(),
        name: 'dashboard',
        routes: [
          GoRoute(
            path: 'pos',
            builder: (context, state) => const RetailPOSScreen(),
            name: 'retail_pos',
          ),
          GoRoute(
            path: 'wholesale-pos',
            builder: (context, state) => const WholesalePOSScreen(),
            name: 'wholesale_pos',
          ),
          GoRoute(
            path: 'inventory',
            builder: (context, state) => const InventoryListScreen(),
            name: 'inventory',
          ),
          GoRoute(
            path: 'customers',
            builder: (context, state) => const CustomerListScreen(),
            name: 'customers',
          ),
          GoRoute(
            path: 'reports/sales',
            builder: (context, state) => const SalesReportScreen(),
            name: 'sales_report',
          ),
          GoRoute(
            path: 'reports/inventory',
            builder: (context, state) => const InventoryReportScreen(),
            name: 'inventory_report',
          ),
          GoRoute(
            path: 'reports/customers',
            builder: (context, state) => const CustomerReportScreen(),
            name: 'customer_report',
          ),
          GoRoute(
            path: 'reports/profit',
            builder: (context, state) => const ProfitReportScreen(),
            name: 'profit_report',
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const AppSettingsScreen(),
            name: 'settings',
          ),
        ],
      ),

      // Item details
      GoRoute(
        path: '/item/:id',
        builder: (context, state) => const ItemDetailScreen(),
        name: 'item_details',
      ),

      // Customer details
      GoRoute(
        path: '/customer/:id',
        builder: (context, state) => const CustomerDetailScreen(),
        name: 'customer_details',
      ),

      // Customer wallet
      GoRoute(
        path: '/customer/:id/wallet',
        builder: (context, state) => const WalletScreen(),
        name: 'customer_wallet',
      ),

      // Payment screen
      GoRoute(
        path: '/payment',
        builder: (context, state) => const PaymentScreen(),
        name: 'payment',
      ),

      // Admin routes
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
        name: 'admin_dashboard',
        routes: [
          GoRoute(
            path: 'users',
            builder: (context, state) => const Text('User Management'),
            name: 'admin_users',
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const SalesReportScreen(),
            name: 'admin_reports',
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const AppSettingsScreen(),
            name: 'admin_settings',
          ),
        ],
      ),

      // Wholesaler routes
      GoRoute(
        path: '/wholesale-dashboard',
        builder: (context, state) => const WholesaleDashboard(),
        name: 'wholesale_dashboard',
        routes: [
          GoRoute(
            path: 'orders',
            builder: (context, state) => const Text('Wholesale Orders'),
            name: 'wholesale_orders',
          ),
          GoRoute(
            path: 'suppliers',
            builder: (context, state) => const Text('Supplier Management'),
            name: 'wholesale_suppliers',
          ),
        ],
      ),

      // Error route
      GoRoute(
        path: 'error',
        builder: (context, state) => const ErrorScreen(),
        name: 'error',
      ),

      // Redirects
      GoRoute(
        path: '*',
        builder: (context, state) => RedirectRoute(
          path: '/',
          name: 'not_found',
        ),
      ),
    ],
    errorBuilder: (context, state) {
      return ErrorScreen(error: state.error?.toString());
    },
  );
});

class _GoRouterNotifier extends ChangeNotifier {
  _GoRouterNotifier(Ref ref) {
    ref.listen<AuthFlowState>(authFlowProvider, (_, __) => notifyListeners());
  }
}

class ErrorScreen extends StatelessWidget {
  final String? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0x66FFFFFF),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error ?? 'An error occurred',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: 14,
                  textAlign: TextAlign.center,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: () {
                  // Navigate back to home
                  context.go('/');
                },
                text: 'Go Back',
                backgroundColor: const Color(0xFF0D9488),
              ),
            ],
          ),
        ),
      ),
    );
  }
}