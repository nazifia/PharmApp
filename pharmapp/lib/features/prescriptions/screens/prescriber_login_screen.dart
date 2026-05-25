import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/prescriber_provider.dart';

class PrescriberLoginScreen extends ConsumerStatefulWidget {
  const PrescriberLoginScreen({super.key});

  @override
  ConsumerState<PrescriberLoginScreen> createState() =>
      _PrescriberLoginScreenState();
}

class _PrescriberLoginScreenState extends ConsumerState<PrescriberLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final p = await ref
        .read(prescriberNotifierProvider.notifier)
        .loginPrescriber(_phoneCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (p != null) {
      context.go('/prescriber-portal');
    } else {
      final err = ref.read(prescriberNotifierProvider).error?.toString() ??
          'Login failed. Check your credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(prescriberNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1A0A2E), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative blobs
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.07),
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
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Icon + heading
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        border: Border.all(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.3),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.25),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.medical_services_rounded,
                          color: EnhancedTheme.accentPurple, size: 38),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Prescriber Sign In',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Access your prescriber portal',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),

                    const SizedBox(height: 40),

                    // Login card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.5),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Phone
                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDeco(
                                    label: 'Phone Number',
                                    icon: Icons.phone_rounded,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Enter your phone number'
                                          : null,
                                ),

                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDeco(
                                    label: 'Password',
                                    icon: Icons.lock_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'Enter your password'
                                          : null,
                                ),

                                const SizedBox(height: 28),

                                // Sign In button
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: EnhancedTheme.accentPurple,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          EnhancedTheme.accentPurple.withValues(alpha: 0.5),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5),
                                          )
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 13)),
                        TextButton(
                          onPressed: () => context.go('/register-prescriber'),
                          child: const Text(
                            'Register here',
                            style: TextStyle(
                                color: EnhancedTheme.accentPurple,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon:
            Icon(icon, color: EnhancedTheme.accentPurple, size: 18),
        suffixIcon: suffix,
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
          borderSide:
              BorderSide(color: EnhancedTheme.accentPurple, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: EnhancedTheme.errorRed),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: EnhancedTheme.errorRed, width: 1.5),
        ),
      );
}
