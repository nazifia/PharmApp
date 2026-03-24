import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';

class RegisterOrgScreen extends ConsumerStatefulWidget {
  const RegisterOrgScreen({super.key});

  @override
  ConsumerState<RegisterOrgScreen> createState() => _RegisterOrgScreenState();
}

class _RegisterOrgScreenState extends ConsumerState<RegisterOrgScreen>
    with SingleTickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _orgNameCtrl     = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _addressCtrl     = TextEditingController();
  bool _obscurePassword  = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _addressCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authFlowProvider.notifier).registerOrg(
      orgName:  _orgNameCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
      address:  _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
    );
  }

  // ── Light-mode constants (same as LoginScreen) ───────────────────────────
  static const _bg1         = Color(0xFFE0F2FE);
  static const _bg2         = Color(0xFFF0FAFA);
  static const _bg3         = Color(0xFFF8FAFC);
  static const _textDark    = Color(0xFF0F172A);
  static const _textMid     = Color(0xFF334155);
  static const _textSub     = Color(0xFF64748B);
  static const _textHint    = Color(0xFF94A3B8);
  static const _inputFill   = Color(0xFFF1F5F9);
  static const _inputBorder = Color(0xFFCBD5E1);
  static const _cardBg      = Colors.white;
  static const _cardBorder  = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthFlowState>(authFlowProvider, (prev, next) {
      if (next == AuthFlowState.authenticated) {
        context.go('/admin-dashboard');
      }
      if (next == AuthFlowState.error) {
        final msg = ref.read(authFlowProvider.notifier).errorMessage ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: EnhancedTheme.errorRed),
        );
      }
    });

    final authState = ref.watch(authFlowProvider);
    final isLoading = authState == AuthFlowState.registering;

    return Scaffold(
      backgroundColor: _bg3,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bg1, _bg2, _bg3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative blobs
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.09),
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
                    const SizedBox(height: 32),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildCard(isLoading),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: isLoading ? null : () => context.go('/login'),
                      child: const Text(
                        'Already registered? Sign in',
                        style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13),
                      ),
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                EnhancedTheme.accentCyan.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.business_rounded, size: 46, color: EnhancedTheme.primaryTeal),
        ),
        const SizedBox(height: 14),
        const Text('Register Your Pharmacy',
            style: TextStyle(color: _textDark, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        const Text('Create a new organization account',
            style: TextStyle(color: _textSub, fontSize: 13)),
      ],
    );
  }

  Widget _buildCard(bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Organization Details',
                    style: TextStyle(color: _textDark, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('You will be the Admin of this pharmacy',
                    style: TextStyle(color: _textSub, fontSize: 12)),
                const SizedBox(height: 24),

                // Pharmacy name
                CustomTextField(
                  controller: _orgNameCtrl,
                  labelText: 'Pharmacy Name',
                  hintText: 'e.g. Lagos Central Pharmacy',
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(Icons.local_pharmacy_rounded, color: EnhancedTheme.primaryTeal),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter pharmacy name';
                    if (v.trim().length < 3) return 'Name is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Admin phone
                CustomTextField(
                  controller: _phoneCtrl,
                  labelText: 'Admin Phone Number',
                  hintText: '+234 801 234 5678',
                  keyboardType: TextInputType.phone,
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(Icons.phone_outlined, color: EnhancedTheme.primaryTeal),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter phone number';
                    if (v.trim().length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                CustomTextField(
                  controller: _passwordCtrl,
                  labelText: 'Admin Password',
                  hintText: '••••••••',
                  obscureText: _obscurePassword,
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: EnhancedTheme.primaryTeal),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _textHint,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Address (optional)
                CustomTextField(
                  controller: _addressCtrl,
                  labelText: 'Address (optional)',
                  hintText: '12 Broad Street, Lagos',
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(Icons.location_on_outlined, color: EnhancedTheme.primaryTeal),
                ),
                const SizedBox(height: 24),

                // Register button
                SizedBox(
                  height: 52,
                  child: CustomButton(
                    text: isLoading ? 'Creating account…' : 'Register Pharmacy',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _handleRegister,
                    backgroundColor: EnhancedTheme.primaryTeal,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
