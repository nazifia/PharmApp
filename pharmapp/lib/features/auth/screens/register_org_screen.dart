import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final _formKey      = GlobalKey<FormState>();
  final _orgNameCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _addressCtrl  = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  // ── Light-mode constants ──────────────────────────────────────────────────
  static const _bg1        = Color(0xFFE0F2FE);
  static const _bg2        = Color(0xFFF0FAFA);
  static const _bg3        = Color(0xFFF8FAFC);
  static const _textDark   = Color(0xFF0F172A);
  static const _textMid    = Color(0xFF334155);
  static const _textSub    = Color(0xFF64748B);
  static const _textHint   = Color(0xFF94A3B8);
  static const _inputFill  = Color(0xFFF1F5F9);
  static const _inputBorder = Color(0xFFCBD5E1);
  static const _cardBg     = Colors.white;
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
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
      address:  _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthFlowState>(authFlowProvider, (prev, next) {
      if (next == AuthFlowState.authenticated) {
        context.go('/admin-dashboard');
      }
      if (next == AuthFlowState.error) {
        final msg = ref.read(authFlowProvider.notifier).errorMessage ??
            'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: EnhancedTheme.errorRed,
          ),
        );
      }
    });

    final authState = ref.watch(authFlowProvider);
    final isLoading = authState == AuthFlowState.registering;

    return Scaffold(
      backgroundColor: _bg3,
      body: Stack(
        children: [
          // ── Rich background gradient ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bg1, _bg2, _bg3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative blob — top right ─────────────────────────────────
          Positioned(
            top: -100, right: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          // ── Decorative blob — bottom left ───────────────────────────────
          Positioned(
            bottom: -120, left: -90,
            child: Container(
              width: 360, height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.accentCyan.withValues(alpha: 0.14),
                  EnhancedTheme.accentCyan.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          // ── Decorative blob — mid right ─────────────────────────────────
          Positioned(
            top: 240, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.07),
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
                    const SizedBox(height: 40),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildCard(isLoading),
                    const SizedBox(height: 24),
                    _buildSignInLink(isLoading),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        // Icon with layered glow
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.22),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.0),
                ]),
              ),
            ),
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.40),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.business_rounded,
                size: 44, color: Colors.black,
              ),
            ),
          ],
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: 20),

        Text(
          'Register Your Pharmacy',
          style: GoogleFonts.outfit(
            color: _textDark,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 6),

        Text(
          'Create your organisation and become the Admin',
          style: GoogleFonts.inter(
            color: _textSub,
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 250.ms, duration: 500.ms),
      ],
    );
  }

  // ── Form card ───────────────────────────────────────────────────────────────
  Widget _buildCard(bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Section header ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 4, height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [
                            EnhancedTheme.primaryTeal,
                            EnhancedTheme.accentCyan,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organisation Details',
                          style: GoogleFonts.outfit(
                            color: _textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'You will be the Admin of this pharmacy',
                          style: GoogleFonts.inter(
                            color: _textSub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Pharmacy name ───────────────────────────────────────
                CustomTextField(
                  controller: _orgNameCtrl,
                  labelText: 'Pharmacy Name',
                  hintText: 'e.g. Lagos Central Pharmacy',
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 24, height: 24,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter pharmacy name';
                    }
                    if (v.trim().length < 3) return 'Name is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Admin phone ─────────────────────────────────────────
                CustomTextField(
                  controller: _phoneCtrl,
                  labelText: 'Admin Phone Number',
                  hintText: '+234 801 234 5678',
                  keyboardType: TextInputType.phone,
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: EnhancedTheme.primaryTeal,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter phone number';
                    }
                    if (v.trim().length < 10) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Password ────────────────────────────────────────────
                CustomTextField(
                  controller: _passwordCtrl,
                  labelText: 'Admin Password',
                  hintText: '••••••••',
                  obscureText: _obscurePassword,
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: EnhancedTheme.primaryTeal,
                  ),
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
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'[A-Za-z]').hasMatch(v)) {
                      return 'Password must contain at least one letter';
                    }
                    if (!RegExp(r'\d').hasMatch(v)) {
                      return 'Password must contain at least one digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Address (optional) ──────────────────────────────────
                CustomTextField(
                  controller: _addressCtrl,
                  labelText: 'Address (optional)',
                  hintText: '12 Broad Street, Lagos',
                  textColor: _textMid,
                  fillColor: _inputFill,
                  enabledBorderColor: _inputBorder,
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: EnhancedTheme.primaryTeal,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Gradient register button ────────────────────────────
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isLoading
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFF0D9488),
                              Color(0xFF06B6D4),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: isLoading
                        ? EnhancedTheme.primaryTeal.withValues(alpha: 0.6)
                        : null,
                    boxShadow: isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: EnhancedTheme.primaryTeal
                                  .withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: CustomButton(
                    text: isLoading ? 'Creating account…' : 'Register Pharmacy',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _handleRegister,
                    backgroundColor: Colors.transparent,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 500.ms)
        .slideY(begin: 0.12, end: 0);
  }

  // ── Sign-in link ─────────────────────────────────────────────────────────
  Widget _buildSignInLink(bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already registered? ',
          style: GoogleFonts.inter(color: _textSub, fontSize: 13),
        ),
        GestureDetector(
          onTap: isLoading ? null : () => context.go('/login'),
          child: Text(
            'Sign in',
            style: GoogleFonts.inter(
              color: EnhancedTheme.primaryTeal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 450.ms, duration: 400.ms);
  }
}
