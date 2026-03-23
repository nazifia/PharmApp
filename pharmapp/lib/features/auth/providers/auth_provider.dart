import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/shared/models/user.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

// ── Token / User state ────────────────────────────────────────────────────────

export '../../../core/network/api_client.dart' show authTokenProvider;

/// Holds the authenticated [User] profile.
final currentUserProvider = StateProvider<User?>((ref) => null);

// ── Repository provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return AuthRepository.local();
  return AuthRepository.remote(ref.watch(dioProvider));
});

// ── Auth flow state ───────────────────────────────────────────────────────────

enum AuthFlowState { initial, loggingIn, authenticated, error }

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
