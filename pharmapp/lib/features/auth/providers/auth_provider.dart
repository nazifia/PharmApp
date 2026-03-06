import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

// StateProvider to hold the JWT session token
final authTokenProvider = StateProvider<String?>((ref) => null);

// Provides the singleton AuthRepository injected with the global Dio client
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

// A simple enum to manage the UI states during login/verification
enum AuthFlowState { initial, requestingOtp, otpSent, verifyingOtp, authenticated, error }

class AuthNotifier extends StateNotifier<AuthFlowState> {
  final Ref _ref;
  String? _errorMessage;

  AuthNotifier(this._ref) : super(AuthFlowState.initial);

  String? get errorMessage => _errorMessage;

  // 1. Send OTP Request
  Future<void> submitPhoneNumber(String phone) async {
    _errorMessage = null;
    state = AuthFlowState.requestingOtp;

    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.requestOtp(phone);
      
      state = AuthFlowState.otpSent;
    } catch (e) {
      _errorMessage = e.toString();
      state = AuthFlowState.error;
    }
  }

  // 2. Submit OTP Code
  Future<void> verifyOtp(String phone, String otp) async {
    _errorMessage = null;
    state = AuthFlowState.verifyingOtp;

    try {
      final repo = _ref.read(authRepositoryProvider);
      final result = await repo.verifyOtp(phone, otp);
      
      // Store the JWT 
      final String token = result['token'];
      _ref.read(authTokenProvider.notifier).state = token;
      
      // Store the User Profile
      // For this step, a real app usually has a currentUserProvider.
      print('User Auth Success: ${result['user'].role}');

      state = AuthFlowState.authenticated;
    } catch (e) {
      _errorMessage = e.toString();
      state = AuthFlowState.error;
    }
  }

  void resetFlow() => state = AuthFlowState.initial;
}

// Global Provider exposing the AuthFlowState and actions
final authFlowProvider = StateNotifierProvider<AuthNotifier, AuthFlowState>((ref) {
  return AuthNotifier(ref);
});
