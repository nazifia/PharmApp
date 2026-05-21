import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/features/prescriptions/providers/prescriber_provider.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;

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
    _phoneController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authFlowProvider.notifier).login(
      _phoneController.text.trim(),
      _passwordController.text,
    );
  }

  void _navigateAfterAuth() {
    final user = ref.read(currentUserProvider);
    final needsBranch = user != null &&
        user.branchId == 0 &&
        user.organizationId != 0 &&
        ref.read(activeBranchProvider) == null &&
        ref.read(hasFeatureProvider(SaasFeature.multiBranch));

    if (needsBranch) {
      context.go('/select-branch');
      return;
    }

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

  void _showPrescriberLoginSheet(BuildContext ctx) {
    final phoneCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey      = GlobalKey<FormState>();
    bool obscure       = true;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medical_services_rounded,
                            color: EnhancedTheme.accentPurple, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Prescriber Sign In',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.phone_rounded,
                            color: EnhancedTheme.accentPurple, size: 18),
                        filled: true,
                        fillColor: Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(
                              color: EnhancedTheme.accentPurple, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your phone number'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.lock_rounded,
                            color: EnhancedTheme.accentPurple, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(
                              color: EnhancedTheme.accentPurple, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Consumer(builder: (_, ref, __) {
                      final loading =
                          ref.watch(prescriberNotifierProvider).isLoading;
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final p = await ref
                                      .read(prescriberNotifierProvider.notifier)
                                      .loginPrescriber(
                                        phoneCtrl.text.trim(),
                                        passwordCtrl.text,
                                      );
                                  if (!sheetCtx.mounted) return;
                                  if (p != null) {
                                    Navigator.of(sheetCtx).pop();
                                    ctx.go('/prescriber-portal');
                                  } else {
                                    final err = ref
                                        .read(prescriberNotifierProvider)
                                        .error
                                        ?.toString() ??
                                        'Login failed';
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(err),
                                        backgroundColor: EnhancedTheme.errorRed,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EnhancedTheme.accentPurple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Sign In',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Light-mode constants ──────────────────────────────────────────────────
  static const _bg1          = Color(0xFFE0F2FE); // light-sky-100
  static const _bg2          = Color(0xFFF0FAFA); // near-white teal tint
  static const _bg3          = Color(0xFFF8FAFC); // slate-50
  static const _textDark     = Color(0xFF0F172A); // slate-900
  static const _textMid      = Color(0xFF334155); // slate-700
  static const _textSub      = Color(0xFF64748B); // slate-500
  static const _textHint     = Color(0xFF94A3B8); // slate-400
  static const _inputFill    = Color(0xFFF1F5F9); // slate-100
  static const _inputBorder  = Color(0xFFCBD5E1); // slate-300
  static const _cardBg       = Colors.white;
  static const _cardBorder   = Color(0xFFE2E8F0); // slate-200
  static const _divider      = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthFlowState>(authFlowProvider, (prev, next) {
      if (next == AuthFlowState.authenticated) {
        _navigateAfterAuth();
      }
      if (next == AuthFlowState.error) {
        final msg = ref.read(authFlowProvider.notifier).errorMessage ?? 'Login failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: EnhancedTheme.errorRed),
        );
      }
    });

    final authState = ref.watch(authFlowProvider);
    final isLoading = authState == AuthFlowState.loggingIn || authState == AuthFlowState.registering;

    // Show org info from last session (stored in shared_preferences via currentUserProvider)
    final savedUser = ref.watch(currentUserProvider);
    final orgName    = savedUser?.organizationName.isNotEmpty == true
        ? savedUser!.organizationName : 'PharmApp';
    final orgAddress = savedUser?.organizationAddress ?? '';
    final orgPhone   = savedUser?.organizationPhone ?? '';
    final orgLogoUrl = savedUser?.organizationLogo.isNotEmpty == true
        ? resolvedMediaUrl(savedUser!.organizationLogo, mediaBase: ref.read(mediaBaseUrlProvider)) : '';

    return Scaffold(
      backgroundColor: _bg3,
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bg1, _bg2, _bg3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative blobs ────────────────────────────────────────────
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

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _buildLogo(orgName, orgAddress, orgPhone, orgLogoUrl),
                    const SizedBox(height: 48),
                    _buildLoginCard(isLoading),
                    const SizedBox(height: 32),
                    Text(
                      '© 2026 $orgName  ·  Pharmacy Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _textHint.withValues(alpha: 0.8), fontSize: 11),
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

  Widget _buildLogo(String orgName, String orgAddress, String orgPhone, String orgLogoUrl) {
    final Widget logoImage = orgLogoUrl.isNotEmpty
        ? Image.network(
            orgLogoUrl,
            width: 100, height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/icons/app_icon.png',
              width: 100, height: 100,
              fit: BoxFit.cover,
            ),
          )
        : Image.asset(
            'assets/icons/app_icon.png',
            width: 100, height: 100,
            fit: BoxFit.cover,
          );
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: logoImage,
          ),
        ),
        const SizedBox(height: 16),
        Text(orgName,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textDark,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        if (orgAddress.isNotEmpty) ...[
          Text(orgAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSub, fontSize: 12)),
          const SizedBox(height: 2),
        ],
        if (orgPhone.isNotEmpty) ...[
          Text(orgPhone,
              style: const TextStyle(color: _textSub, fontSize: 12)),
          const SizedBox(height: 2),
        ],
        if (orgAddress.isEmpty && orgPhone.isEmpty)
          const Text('Pharmacy Management System',
              style: TextStyle(color: _textSub, fontSize: 13)),
      ],
    );
  }

  Widget _buildLoginCard(bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(32),
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
                const Text('Welcome back',
                    style: TextStyle(
                        color: _textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Sign in with your phone number and password',
                    style: TextStyle(color: _textSub, fontSize: 13)),
                const SizedBox(height: 28),

                // Phone input
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  hintText: '+234 801 234 5678',
                  keyboardType: TextInputType.phone,
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: EnhancedTheme.primaryTeal),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                    if (v.trim().length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password input
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  hintText: '••••••••',
                  obscureText: _obscurePassword,
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: EnhancedTheme.primaryTeal),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sign In button
                SizedBox(
                  height: 52,
                  child: CustomButton(
                    text: isLoading ? 'Signing in…' : 'Sign In',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _handleLogin,
                    backgroundColor: EnhancedTheme.primaryTeal,
                    width: double.infinity,
                  ),
                ),

                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: _divider)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Secure Login',
                          style: TextStyle(
                              color: _textHint, fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: _divider)),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading ? null : () => context.go('/register-org'),
                  child: const Text(
                    'New pharmacy? Register here',
                    style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.go('/register-prescriber'),
                  child: const Text(
                    'Are you a prescriber? Register here',
                    style: TextStyle(
                        color: EnhancedTheme.accentPurple, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => _showPrescriberLoginSheet(context),
                  child: const Text(
                    'Prescriber? Sign in here',
                    style: TextStyle(
                        color: EnhancedTheme.accentPurple, fontSize: 13),
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
