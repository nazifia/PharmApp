import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/models/user.dart';

class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isAuthenticated =>
      _ref.read(authFlowProvider) == AuthFlowState.authenticated;

  User? get currentUser => _ref.read(currentUserProvider);

  String? get authToken => _ref.read(authTokenProvider);

  // ── Auth actions ─────────────────────────────────────────────────────────────

  Future<void> login(String phone, String password) async {
    await _ref.read(authFlowProvider.notifier).login(phone, password);
  }

  /// Restores session from persistent storage (call on app startup).
  Future<bool> checkAuthStatus() async {
    try {
      final prefs    = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      final token    = prefs.getString('auth_token');
      final userData = prefs.getString('current_user');

      if (token != null && userData != null) {
        final user = User.fromJson(jsonDecode(userData) as Map<String, dynamic>);
        _ref.read(authFlowProvider.notifier).restoreSession(token, user);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
    _ref.read(currentUserProvider.notifier).state = null;
    _ref.read(authTokenProvider.notifier).state   = null;
    _ref.read(authFlowProvider.notifier).resetFlow();
  }

  // ── Permissions ───────────────────────────────────────────────────────────────

  List<String> getUserPermissions() {
    switch (currentUser?.role) {
      case 'Admin':
        return [
          'admin', 'manage_users', 'manage_inventory',
          'manage_sales', 'view_reports', 'manage_wholesale',
        ];
      case 'Manager':
        return ['manage_inventory', 'manage_sales', 'view_reports', 'manage_customers'];
      case 'Pharmacist':
      case 'Pharm-Tech':
        return ['manage_inventory', 'manage_sales', 'view_reports'];
      case 'Cashier':
        return ['process_payments', 'view_sales'];
      case 'Salesperson':
        return ['create_sales', 'view_inventory'];
      case 'Wholesale Manager':
      case 'Wholesale Operator':
      case 'Wholesale Salesperson':
        return ['manage_wholesale', 'view_reports'];
      default:
        return [];
    }
  }

  bool hasPermission(String permission) =>
      getUserPermissions().contains(permission);
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));
