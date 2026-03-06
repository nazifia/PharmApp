import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';
import 'package:pharmapp/core/services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final authService = ref.read(authServiceProvider);
        final success = await authService.loginWithPhone(
          _phoneController.text,
          onVerificationCompleted: () {
            setState(() => _isLoading = false);
            // Navigate to role selection
            ref.read(enhancedThemeProvider.notifier).navigateTo('/role-selection');
          },
          onVerificationFailed: () {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Verification failed. Please try again.'),
                backgroundColor: EnhancedTheme.errorRed,
              ),
            );
          },
          onCodeSent: () {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Verification code sent!'),
                backgroundColor: EnhancedTheme.successGreen,
              ),
            );
            // Navigate to code verification
            ref.read(enhancedThemeProvider.notifier).navigateTo('/verify-code');
          },
          onCodeAutoRetrievalTimeout: () {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Auto-retrieval timeout. Please enter code manually.'),
                backgroundColor: EnhancedTheme.warningAmber,
              ),
            );
          },
        );

        if (!success) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Login failed. Please try again.'),
              backgroundColor: EnhancedTheme.errorRed,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EnhancedTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),

                  // Logo and App Name
                  Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: EnhancedTheme.glassLight,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_pharmacy,
                          size: 64,
                          color: EnhancedTheme.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PharmApp',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                      const Text(
                        'Pharmacy Management System',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // Login Form
                  EnhancedTheme.glassContainer(
                    context,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in with your phone number',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Phone Input
                          CustomTextField(
                            controller: _phoneController,
                            labelText: 'Phone Number',
                            hintText: '+91 98765 43210',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.phone),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (value.length < 10) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          // Login Button
                          CustomButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            text: _isLoading ? 'Verifying...' : 'Send Verification Code',
                            isLoading: _isLoading,
                          ),

                          const SizedBox(height: 16),

                          // Alternative Login
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Or continue with',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Social Login Buttons
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  onPressed: () {
                                    // TODO: Implement Google Sign-In
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Google Sign-In coming soon!'),
                                        backgroundColor: EnhancedTheme.infoBlue,
                                      ),
                                    );
                                  },
                                  text: 'Google',
                                  backgroundColor: Colors.white,
                                  foregroundColor: EnhancedTheme.primaryTeal,
                                  icon: const Icon(Icons.google, color: EnhancedTheme.primaryTeal),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CustomButton(
                                  onPressed: () {
                                    // TODO: Implement Facebook Login
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Facebook Login coming soon!'),
                                        backgroundColor: EnhancedTheme.infoBlue,
                                      ),
                                    );
                                  },
                                  text: 'Facebook',
                                  backgroundColor: const Color(0xFF1877F2),
                                  foregroundColor: Colors.white,
                                  icon: const Icon(Icons.facebook, color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Terms and Privacy
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'By continuing, you agree to our',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                    color: EnhancedTheme.accentCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Text(
                                ' and',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    color: EnhancedTheme.accentCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                              ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Footer
                  Column(
                    children: [
                      const Text(
                        'Pharmacy Management Made Simple',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '© 2026 PharmApp. All rights reserved.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}