import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  bool  _isLoading  = false;

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
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: EnhancedTheme.primaryTeal.withValues(alpha:0.12),
                      border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha:0.3)),
                    ),
                    child: const Icon(Icons.waving_hand_rounded, size: 44, color: EnhancedTheme.primaryTeal),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome to PharmApp',
                      style: TextStyle(color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text("Let's complete your profile setup",
                      style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                  const SizedBox(height: 40),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Phone (read-only)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: context.borderColor),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.phone_outlined, color: EnhancedTheme.primaryTeal, size: 18),
                                  const SizedBox(width: 12),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Phone Number', style: TextStyle(color: context.hintColor, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(user?.phoneNumber ?? '—',
                                        style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
                                  ]),
                                ]),
                              ),
                              const SizedBox(height: 20),

                              // Name input
                              CustomTextField(
                                controller: _nameCtrl,
                                labelText: 'Full Name',
                                hintText: 'e.g. Adaeze Okafor',
                                prefixIcon: const Icon(Icons.person_outline, color: EnhancedTheme.primaryTeal),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter your name';
                                  if (v.trim().length < 2) return 'Name too short';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              SizedBox(
                                height: 52,
                                child: CustomButton(
                                  text: _isLoading ? 'Setting up…' : 'Get Started',
                                  isLoading: _isLoading,
                                  onPressed: _isLoading ? null : _complete,
                                  backgroundColor: EnhancedTheme.primaryTeal,
                                  icon: _isLoading ? null : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
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
}
