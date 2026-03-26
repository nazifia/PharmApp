import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  bool _isLoading  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('display_name', _nameCtrl.text.trim());
    } catch (_) {}
    if (!mounted) return;
    context.go(AppShell.roleFallback(ref));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          // ── Background gradient ─────────────────────────────────────────
          Container(decoration: context.bgGradient),

          // ── Decorative glow top-right ───────────────────────────────────
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.accentCyan.withValues(alpha: isDark ? 0.15 : 0.10),
                  EnhancedTheme.accentCyan.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          // ── Decorative glow bottom-left ─────────────────────────────────
          Positioned(
            bottom: -100, left: -70,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.accentPurple.withValues(alpha: isDark ? 0.12 : 0.07),
                  EnhancedTheme.accentPurple.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top nav bar ───────────────────────────────────────────
                _buildNavBar(context),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ── Hero icon ───────────────────────────────────
                        _buildHeroSection(context),

                        const SizedBox(height: 40),

                        // ── Profile card ────────────────────────────────
                        _buildProfileCard(context, user),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation bar ─────────────────────────────────────────────────────────
  Widget _buildNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
            onPressed: () => context.go('/role-selection'),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Profile Setup',
              style: GoogleFonts.outfit(
                color: context.labelColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Step indicator chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Step 2 of 2',
              style: GoogleFonts.inter(
                color: EnhancedTheme.primaryTeal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── Hero section ────────────────────────────────────────────────────────────
  Widget _buildHeroSection(BuildContext context) {
    return Column(
      children: [
        // Layered icon with animated glow
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.0),
                ]),
              ),
            ),
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.45),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                size: 48, color: Colors.white,
              ),
            ),
          ],
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: 22),

        Text(
          'Welcome to PharmApp!',
          style: GoogleFonts.outfit(
            color: context.labelColor,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 8),

        Text(
          "Almost there — let's complete your profile",
          style: GoogleFonts.inter(
            color: context.subLabelColor,
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
      ],
    );
  }

  // ── Profile card ────────────────────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context, dynamic user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Section label ─────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 4, height: 20,
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
                    Text(
                      'Your Details',
                      style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── Phone read-only row ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                        EnhancedTheme.accentCyan.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone_outlined,
                          color: EnhancedTheme.primaryTeal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone Number',
                            style: GoogleFonts.inter(
                              color: context.hintColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.phoneNumber ?? '—',
                            style: GoogleFonts.inter(
                              color: context.labelColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.successGreen
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Verified',
                          style: GoogleFonts.inter(
                            color: EnhancedTheme.successGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Full name input ───────────────────────────────────
                CustomTextField(
                  controller: _nameCtrl,
                  labelText: 'Full Name',
                  hintText: 'e.g. Adaeze Okafor',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: EnhancedTheme.primaryTeal,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your name';
                    }
                    if (v.trim().length < 2) return 'Name too short';
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ── Gradient get-started button ───────────────────────
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFF0D9488),
                              Color(0xFF06B6D4),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: _isLoading
                        ? EnhancedTheme.primaryTeal.withValues(alpha: 0.6)
                        : null,
                    boxShadow: _isLoading
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
                    text: _isLoading ? 'Setting up…' : 'Get Started',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _complete,
                    backgroundColor: Colors.transparent,
                    icon: _isLoading
                        ? null
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
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
}
