import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authFlowProvider);
    final authNotifier = ref.read(authFlowProvider.notifier);
    
    // The go_router will handle the authenticated redirect automatically.
    // We only need to listen for errors to show the snackbar.
    ref.listen(authFlowProvider, (previous, next) {
      if (next == AuthFlowState.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authNotifier.errorMessage ?? 'An error occurred'),
            backgroundColor: Colors.red.shade800,
          )
        );
      }
    });

    final isOtpMode = authState == AuthFlowState.otpSent || authState == AuthFlowState.verifyingOtp;
    final isLoading = authState == AuthFlowState.requestingOtp || authState == AuthFlowState.verifyingOtp;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0F2FE), Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                color: Colors.white.withOpacity(0.8), // Pseudo-glass
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo / Title
                      Center(
                        child: Text(
                          'PharmApp',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ).animate().fade(duration: 500.ms).slideY(begin: -0.2, end: 0),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          isOtpMode ? 'Enter the code sent to your phone' : 'Sign in with your phone number',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ).animate().fade(delay: 200.ms),
                      ),
                      const SizedBox(height: 36),
                      
                      // Dynamic Input Fields
                      if (!isOtpMode)
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !isLoading,
                          decoration: const InputDecoration(
                            hintText: '+1 (555) 000-0000',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ).animate().fade(delay: 300.ms).slideX(begin: 0.1)
                      else
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          enabled: !isLoading,
                          textAlign: TextAlign.center,
                          style: const TextStyle(letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
                          maxLength: 6,
                          decoration: const InputDecoration(
                            hintText: '000000',
                            counterText: '',
                          ),
                        ).animate().fade(duration: 300.ms).slideX(begin: 0.1),

                      const SizedBox(height: 24),
                      
                      // Dynamic Actions
                      ElevatedButton(
                        onPressed: isLoading ? null : () {
                          if (!isOtpMode) {
                             if (_phoneController.text.isNotEmpty) {
                               authNotifier.submitPhoneNumber(_phoneController.text);
                             }
                          } else {
                             if (_otpController.text.length == 6) {
                               authNotifier.verifyOtp(_phoneController.text, _otpController.text);
                             }
                          }
                        },
                        child: isLoading 
                           ? const SizedBox(
                               height: 20, width: 20, 
                               child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                             )
                           : Text(!isOtpMode ? 'Send Code' : 'Verify & Login'),
                      ).animate().fade(delay: 400.ms).scale(begin: const Offset(0.9, 0.9)),

                      if (isOtpMode && !isLoading) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => authNotifier.resetFlow(),
                          child: const Text('Change Phone Number'),
                        )
                      ]
                    ],
                  ),
                ),
              ).animate().fade(duration: 600.ms).scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
        ],
      ),
    );
  }
}
