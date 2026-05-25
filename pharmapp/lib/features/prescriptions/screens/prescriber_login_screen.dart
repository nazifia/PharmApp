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
      backgroundColor: const Color(0xFFF5F3FF),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF), Color(0xFFEFF6FF)],
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
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.06),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: EnhancedTheme.accentPurple.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: EnhancedTheme.accentPurple.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: EnhancedTheme.accentPurple.withValues(alpha: 0.7), size: 16),
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
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                        border: Border.all(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.25),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.18),
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
                          color: const Color(0xFF1E1B4B),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Access your prescriber portal',
                      style: TextStyle(
                          color: EnhancedTheme.accentPurple.withValues(alpha: 0.6),
                          fontSize: 14),
                    ),

                    const SizedBox(height: 40),

                    // Login card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.08),
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
                            // Phone
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Color(0xFF1E1B4B)),
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
                              style: const TextStyle(color: Color(0xFF1E1B4B)),
                              decoration: _inputDeco(
                                label: 'Password',
                                icon: Icons.lock_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: EnhancedTheme.accentPurple.withValues(alpha: 0.4),
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
                                      EnhancedTheme.accentPurple.withValues(alpha: 0.4),
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

                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?",
                            style: TextStyle(
                                color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                                fontSize: 13)),
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
        labelStyle: TextStyle(color: const Color(0xFF1E1B4B).withValues(alpha: 0.5)),
        prefixIcon:
            Icon(icon, color: EnhancedTheme.accentPurple, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F3FF),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: EnhancedTheme.accentPurple.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: EnhancedTheme.accentPurple.withValues(alpha: 0.15)),
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
