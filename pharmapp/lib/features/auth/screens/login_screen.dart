import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authFlowProvider.notifier).submitPhoneNumber(_phoneController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state transitions
    ref.listen<AuthFlowState>(authFlowProvider, (prev, next) {
      if (next == AuthFlowState.otpSent) {
        context.go('/verify-code');
      }
      if (next == AuthFlowState.error) {
        final msg = ref.read(authFlowProvider.notifier).errorMessage ?? 'Login failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: EnhancedTheme.errorRed),
        );
      }
    });

    final authState = ref.watch(authFlowProvider);
    final isLoading = authState == AuthFlowState.requestingOtp;

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Decorative blobs
          Positioned(top: -80, right: -60,
            child: Container(width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.primaryTeal.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(bottom: -100, left: -80,
            child: Container(width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentCyan.withOpacity(0.06),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // Logo
                    _buildLogo(context),

                    const SizedBox(height: 56),

                    // Login card
                    _buildLoginCard(context, isLoading),

                    const SizedBox(height: 32),

                    // Footer
                    Text(
                      '© 2026 PharmApp  ·  Pharmacy Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                EnhancedTheme.primaryTeal.withOpacity(0.3),
                EnhancedTheme.accentCyan.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: const Icon(Icons.local_pharmacy_rounded,
              size: 52, color: EnhancedTheme.primaryTeal),
        ),
        const SizedBox(height: 16),
        const Text('PharmApp',
            style: TextStyle(color: Colors.white, fontSize: 30,
                fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('Pharmacy Management System',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Welcome back',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Sign in with your registered phone number',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 28),

                // Phone input
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  hintText: '+234 801 234 5678',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, color: EnhancedTheme.primaryTeal),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                    if (v.trim().length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Send OTP button
                SizedBox(
                  height: 52,
                  child: CustomButton(
                    text: isLoading ? 'Sending code…' : 'Send Verification Code',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _handleSendOtp,
                    backgroundColor: EnhancedTheme.primaryTeal,
                    width: double.infinity,
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Secure OTP Login',
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
