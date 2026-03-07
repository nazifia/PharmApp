import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/shared/models/user.dart';
import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

// ── Token / User state ────────────────────────────────────────────────────────

/// Holds the raw JWT access token in memory.
final authTokenProvider = StateProvider<String?>((ref) => null);

/// Holds the authenticated [User] profile.
final currentUserProvider = StateProvider<User?>((ref) => null);

// ── Repository provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

// ── Auth flow state ───────────────────────────────────────────────────────────

enum AuthFlowState {
  initial,
  requestingOtp,
  otpSent,
  verifyingOtp,
  authenticated,
  error,
}

class AuthNotifier extends StateNotifier<AuthFlowState> {
  final Ref _ref;
  String? _errorMessage;

  AuthNotifier(this._ref) : super(AuthFlowState.initial);

  String? get errorMessage => _errorMessage;

  // 1 ─ Send OTP ───────────────────────────────────────────────────────────────
  Future<void> submitPhoneNumber(String phone) async {
    _errorMessage = null;
    state = AuthFlowState.requestingOtp;

    try {
      await _ref.read(authRepositoryProvider).requestOtp(phone);
      state = AuthFlowState.otpSent;
    } catch (e) {
      _errorMessage = _friendly(e);
      state = AuthFlowState.error;
    }
  }

  // 2 ─ Verify OTP ─────────────────────────────────────────────────────────────
  Future<void> verifyOtp(String phone, String otp) async {
    _errorMessage = null;
    state = AuthFlowState.verifyingOtp;

    try {
      final result = await _ref.read(authRepositoryProvider).verifyOtp(phone, otp);

      // Store JWT
      final String token = result['token'] as String;
      _ref.read(authTokenProvider.notifier).state = token;

      // Store user profile
      final User user = result['user'] as User;
      _ref.read(currentUserProvider.notifier).state = user;

      // Persist for session restoration on next launch
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token',   token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      state = AuthFlowState.authenticated;
    } catch (e) {
      _errorMessage = _friendly(e);
      state = AuthFlowState.error;
    }
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
