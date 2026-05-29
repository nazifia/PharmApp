import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/services/auth_storage.dart';
import 'package:pharmapp/core/services/offline_credential_store.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/shared/models/branch.dart';
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

  /// Returns true if the JWT [token] is already expired (compares `exp` claim
  /// against wall-clock time). Returns false on any decode failure so that a
  /// malformed-but-present token still reaches the network layer for a proper
  /// 401 rather than silently blocking the session.
  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      // JWT payload is base64url — normalise to standard base64 before decode.
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final data = jsonDecode(
          utf8.decode(base64Decode(payload))) as Map<String, dynamic>;
      final exp = data['exp'];
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch >= (exp as num).toInt() * 1000;
    } catch (_) {
      return false;
    }
  }

  /// Restores session from persistent storage (call on app startup).
  /// First restores the cached user so the UI is immediately available,
  /// then refreshes the profile from the backend in the background so that
  /// any permission changes made via Django admin or the UI are picked up.
  Future<bool> checkAuthStatus() async {
    try {
      final token    = await AuthStorage.read('auth_token');
      final userData = await AuthStorage.read('current_user');

      if (token != null && userData != null) {
        // Reject locally-expired JWTs before restoring the session.
        // This prevents the 401 storm that occurs when expired credentials
        // are restored and every startup provider fires a rejected request.
        if (_isJwtExpired(token)) {
          await AuthStorage.delete('auth_token');
          await AuthStorage.delete('current_user');
          return false;
        }
        final user = User.fromJson(jsonDecode(userData) as Map<String, dynamic>);
        // 1. Restore immediately from cache so the UI is usable right away
        _ref.read(authFlowProvider.notifier).restoreSession(token, user);
        // 2. Restore active branch so user isn't re-prompted every app start.
        //    If the user has a backend-assigned branch (branchId != 0), use it
        //    directly — no manual selection ever needed for that account.
        final prefs      = await SharedPreferences.getInstance();
        final branchData = prefs.getString('active_branch');
        if (user.branchId != 0) {
          _ref.read(activeBranchProvider.notifier).state = Branch(
            id:   user.branchId,
            name: user.branchName,
          );
        } else if (branchData != null) {
          final branch = Branch.fromJson(
              jsonDecode(branchData) as Map<String, dynamic>);
          _ref.read(activeBranchProvider.notifier).state = branch;
        }
        // 3. Refresh from backend in background — picks up permission changes
        _ref.read(authFlowProvider.notifier).refreshProfile().ignore();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Explicitly refreshes the current user's profile from the backend.
  /// Call this after any permission change or when the app resumes.
  Future<void> refreshProfile() =>
      _ref.read(authFlowProvider.notifier).refreshProfile();

  Future<void> logout() async {
    await AuthStorage.delete('auth_token');
    await AuthStorage.delete('current_user');
    await OfflineCredentialStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_branch');
    _ref.read(currentUserProvider.notifier).state  = null;
    _ref.read(authTokenProvider.notifier).state    = null;
    _ref.read(activeBranchProvider.notifier).state = null;
    _ref.read(authFlowProvider.notifier).resetFlow();
  }

  // ── Permissions ───────────────────────────────────────────────────────────────

  /// Returns the list of AppPermission keys the current user has access to.
  /// Respects individual overrides from the backend (via Rbac.can).
  List<String> getUserPermissions() {
    const all = [
      AppPermission.viewReports,      AppPermission.manageUsers,
      AppPermission.manageSettings,   AppPermission.viewNotifications,
      AppPermission.viewSubscription, AppPermission.manageExpenses,
      AppPermission.processPayments,  AppPermission.manageSuppliers,
      AppPermission.writeInventory,   AppPermission.readInventory,
      AppPermission.retailPOS,        AppPermission.wholesalePOS,
      AppPermission.viewWholesale,    AppPermission.writeCustomers,
      AppPermission.readCustomers,    AppPermission.manageTransfers,
    ];
    return all.where((p) => Rbac.can(currentUser, p)).toList();
  }

  bool hasPermission(String permission) => Rbac.can(currentUser, permission);
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));
