import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/networks/providers/network_provider.dart';

class CreateNetworkScreen extends ConsumerStatefulWidget {
  const CreateNetworkScreen({super.key});

  @override
  ConsumerState<CreateNetworkScreen> createState() =>
      _CreateNetworkScreenState();
}

class _CreateNetworkScreenState extends ConsumerState<CreateNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final network = await ref.read(networkNotifierProvider.notifier).createNetwork(
          _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(networkNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.error_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Error: ${state.error}',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
    } else if (network != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${network.name} created successfully',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
      context.go('/dashboard/network');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(networkNotifierProvider);
    final isLoading = notifierState.isLoading;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(context),
                          const SizedBox(height: 24),
                          _formCard(context, isLoading),
                          const SizedBox(height: 28),
                          _buildSubmitButton(isLoading),
                        ],
                      ),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon:
                Icon(Icons.arrow_back_rounded, color: context.labelColor),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Network',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800),
              ),
              Text(
                'Connect with partner pharmacies',
                style:
                    TextStyle(color: context.subLabelColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1, end: 0),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                EnhancedTheme.accentPurple.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_rounded,
                    color: EnhancedTheme.accentPurple, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pharmacy Network',
                      style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Create a network to share prescriptions, stock visibility, and coordinate with trusted pharmacy partners.',
                      style: TextStyle(
                          color: context.subLabelColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _formCard(BuildContext context, bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(context, 'Network Name *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                enabled: !isLoading,
                style: TextStyle(color: context.labelColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Lagos Central Pharmacy Network',
                  hintStyle:
                      TextStyle(color: context.hintColor, fontSize: 13),
                  prefixIcon: Icon(Icons.hub_rounded,
                      color: context.hintColor, size: 18),
                  filled: true,
                  fillColor: context.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: context.borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: EnhancedTheme.accentPurple, width: 1.5)),
                  errorStyle:
                      const TextStyle(color: EnhancedTheme.errorRed),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _fieldLabel(context, 'Description (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                enabled: !isLoading,
                maxLines: 3,
                style: TextStyle(color: context.labelColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Describe the purpose of this network…',
                  hintStyle:
                      TextStyle(color: context.hintColor, fontSize: 13),
                  filled: true,
                  fillColor: context.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: context.borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: EnhancedTheme.accentPurple, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: 80.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _fieldLabel(BuildContext context, String label) => Text(
        label,
        style: TextStyle(
          color: context.subLabelColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: EnhancedTheme.accentPurple,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              EnhancedTheme.accentPurple.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hub_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Create Network',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
      ),
    ).animate(delay: 120.ms).fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0);
  }
}
