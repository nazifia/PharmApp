import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final List<TextEditingController> _ctls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _seconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  @override
  void dispose() {
    for (final c in _ctls) c.dispose();
    for (final n in _nodes) n.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _seconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _otp => _ctls.map((c) => c.text).join();

  void _onDigitChanged(int idx, String val) {
    if (val.length == 1 && idx < 5) {
      _nodes[idx + 1].requestFocus();
    } else if (val.isEmpty && idx > 0) {
      _nodes[idx - 1].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  void _verify() {
    if (_otp.length < 6) return;
    ref.read(authFlowProvider.notifier).verifyOtp('', _otp);
  }

  void _resend() {
    if (!_canResend) return;
    for (final c in _ctls) c.clear();
    _nodes[0].requestFocus();
    _startTimer();
    // Trigger resend via submitting the stored phone again is handled by going back
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthFlowState>(authFlowProvider, (prev, next) {
      if (next == AuthFlowState.authenticated) {
        final user = ref.read(currentUserProvider);
        switch (user?.role) {
          case 'Admin':
          case 'Manager':
            context.go('/admin-dashboard');
            break;
          case 'Wholesale Manager':
          case 'Wholesale Operator':
          case 'Wholesale Salesperson':
            context.go('/wholesale-dashboard');
            break;
          default:
            context.go('/dashboard');
        }
      }
      if (next == AuthFlowState.error) {
        final msg = ref.read(authFlowProvider.notifier).errorMessage ?? 'Invalid code';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: EnhancedTheme.errorRed),
        );
        for (final c in _ctls) c.clear();
        _nodes[0].requestFocus();
      }
    });

    final authState  = ref.watch(authFlowProvider);
    final isVerifying = authState == AuthFlowState.verifyingOtp;

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Icon
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: EnhancedTheme.primaryTeal.withOpacity(0.12),
                      border: Border.all(color: EnhancedTheme.primaryTeal.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.sms_outlined, size: 44, color: EnhancedTheme.primaryTeal),
                  ),
                  const SizedBox(height: 20),

                  const Text('Verify your number',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Enter the 6-digit code sent to your phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                  const SizedBox(height: 40),

                  // OTP boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => _otpBox(i)),
                  ),
                  const SizedBox(height: 32),

                  // Verify button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: CustomButton(
                              text: isVerifying ? 'Verifying…' : 'Verify Code',
                              isLoading: isVerifying,
                              onPressed: isVerifying ? null : _verify,
                              backgroundColor: EnhancedTheme.primaryTeal,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text("Didn't receive the code? ",
                                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
                            GestureDetector(
                              onTap: _canResend ? _resend : null,
                              child: Text(
                                _canResend ? 'Resend' : 'Resend in ${_seconds}s',
                                style: TextStyle(
                                  color: _canResend
                                      ? EnhancedTheme.primaryTeal
                                      : Colors.white.withOpacity(0.3),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(
        width: 46, height: 56,
        child: TextField(
          controller: _ctls[i],
          focusNode: _nodes[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _onDigitChanged(i, v),
          style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
