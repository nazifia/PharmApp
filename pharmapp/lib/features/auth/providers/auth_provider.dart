import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/shared/models/user.dart';
import 'package:pharmapp/shared/models/organization.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

// ── Token / User state ────────────────────────────────────────────────────────

export '../../../core/network/api_client.dart' show authTokenProvider;

/// Holds the authenticated [User] profile.
final currentUserProvider = StateProvider<User?>((ref) => null);

/// Derived from the authenticated user — no separate storage needed.
/// Returns null if the user has no org (e.g. local dev, legacy session).
final currentOrganizationProvider = Provider<Organization?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.organizationId == 0) return null;
  return Organization(
    id: user.organizationId,
    name: user.organizationName,
    slug: user.organizationSlug,
    address: user.organizationAddress.isEmpty ? null : user.organizationAddress,
    phone: user.organizationPhone.isEmpty ? null : user.organizationPhone,
    logoUrl: user.organizationLogo.isEmpty ? null : user.organizationLogo,
  );
});

// ── Repository provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return AuthRepository.local();
  return AuthRepository.remote(ref.watch(dioProvider));
});

// ── Auth flow state ───────────────────────────────────────────────────────────

enum AuthFlowState { initial, loggingIn, registering, authenticated, error }

class AuthNotifier extends StateNotifier<AuthFlowState> {
  final Ref _ref;
  String? _errorMessage;

  AuthNotifier(this._ref) : super(AuthFlowState.initial);

  String? get errorMessage => _errorMessage;

  /// Direct phone + password login (no OTP).
  Future<void> login(String phone, String password) async {
    _errorMessage = null;
    state = AuthFlowState.loggingIn;

    try {
      final result = await _ref.read(authRepositoryProvider).login(phone, password);

      final String token = result['token'] as String;
      final User   user  = result['user']  as User;

      _ref.read(authTokenProvider.notifier).state   = token;
      _ref.read(currentUserProvider.notifier).state = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token',   token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      state = AuthFlowState.authenticated;
    } catch (e) {
      _errorMessage = _friendly(e);
      state = AuthFlowState.error;
    }
  }

  /// Called by [AuthService.checkAuthStatus] to restore a persisted session
  /// without going through the login network call.
  void restoreSession(String token, User user) {
    _ref.read(authTokenProvider.notifier).state   = token;
    _ref.read(currentUserProvider.notifier).state = user;
    state = AuthFlowState.authenticated;
  }

  /// Register a new pharmacy organization + first admin user.
  Future<void> registerOrg({
    required String orgName,
    required String phone,
    required String password,
    String? address,
  }) async {
    _errorMessage = null;
    state = AuthFlowState.registering;
    try {
      final result = await _ref.read(authRepositoryProvider).registerOrg(
            orgName: orgName,
            phone: phone,
            password: password,
            address: address,
          );
      final String token = result['token'] as String;
      final User user = result['user'] as User;

      _ref.read(authTokenProvider.notifier).state = token;
      _ref.read(currentUserProvider.notifier).state = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      state = AuthFlowState.authenticated;
    } catch (e) {
      _errorMessage = _friendly(e);
      state = AuthFlowState.error;
    }
  }

  /// Re-fetches the current user's profile from the backend and updates
  /// both the in-memory provider and the SharedPreferences cache.
  /// Call this after session restore, after saving permission overrides,
  /// or whenever the app resumes from background.
  Future<void> refreshProfile() async {
    final current = _ref.read(currentUserProvider);
    if (current == null) return; // not logged in
    try {
      final fresh = await _ref
          .read(authRepositoryProvider)
          .fetchCurrentUser(current);
      _ref.read(currentUserProvider.notifier).state = fresh;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(fresh.toJson()));
    } catch (_) {
      // Silently ignore — keep the cached user
    }
  }

  /// Uploads a new logo for the org and patches the cached user so the
  /// drawer updates immediately without a full re-login.
  Future<void> uploadOrgLogo(XFile imageFile) async {
    final newLogoUrl = await _ref.read(authRepositoryProvider).uploadOrgLogo(imageFile);
    final current = _ref.read(currentUserProvider);
    if (current == null) return;
    final updated = current.copyWith(organizationLogo: newLogoUrl);
    _ref.read(currentUserProvider.notifier).state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(updated.toJson()));
  }

  void resetFlow() {
    _errorMessage = null;
    state = AuthFlowState.initial;
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('Exception:')) return msg.replaceFirst('Exception: ', '');
    return msg;
  }
}

final authFlowProvider =
    StateNotifierProvider<AuthNotifier, AuthFlowState>((ref) {
  return AuthNotifier(ref);
});
