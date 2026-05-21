import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/hospital.dart';
import '../providers/prescriber_provider.dart';
import 'prescriber_form_screen.dart' show HospitalPickerSheet;

class PrescriberRegistrationScreen extends ConsumerStatefulWidget {
  const PrescriberRegistrationScreen({super.key});

  @override
  ConsumerState<PrescriberRegistrationScreen> createState() =>
      _PrescriberRegistrationScreenState();
}

class _PrescriberRegistrationScreenState
    extends ConsumerState<PrescriberRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  Hospital? _selectedHospital;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  static const _specialties = [
    'General Practitioner',
    'Internal Medicine',
    'Pediatrician',
    'Cardiologist',
    'Neurologist',
    'Dermatologist',
    'Gynecologist',
    'Ophthalmologist',
    'ENT Specialist',
    'Orthopedic Surgeon',
    'Psychiatrist',
    'Oncologist',
    'Endocrinologist',
    'Gastroenterologist',
    'Pulmonologist',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _specialtyCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'password': _passwordCtrl.text,
      if (_licenseCtrl.text.trim().isNotEmpty)
        'license_number': _licenseCtrl.text.trim(),
      if (_specialtyCtrl.text.trim().isNotEmpty)
        'specialty': _specialtyCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_selectedHospital != null) 'hospital_id': _selectedHospital!.id,
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
    };

    final result =
        await ref.read(prescriberNotifierProvider.notifier).registerPrescriber(data);

    if (!mounted) return;

    final state = ref.read(prescriberNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed: ${state.error}'),
        backgroundColor: EnhancedTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (result != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(name: result.name),
      );
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(prescriberNotifierProvider);
    final isLoading = notifierState.isLoading;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          // Background gradient
          Container(decoration: context.bgGradient),

          // Decorative blobs
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildCard(isLoading),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Already registered? Sign in',
                        style: TextStyle(
                            color: EnhancedTheme.accentCyan, fontSize: 13),
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
            border: Border.all(
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.3),
                width: 1.5),
          ),
          child: const Icon(Icons.medical_services_rounded,
              color: EnhancedTheme.accentPurple, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Prescriber Registration',
          style: GoogleFonts.outfit(
              color: context.labelColor,
              fontSize: 26,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Register as a licensed prescriber\nNo pharmacy account needed',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.subLabelColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCard(bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor, width: 1.5),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _field(_nameCtrl, 'Full Name *',
                    icon: Icons.person_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),

                // License number (optional)
                _field(_licenseCtrl, 'License / Registration Number',
                    icon: Icons.badge_rounded),
                const SizedBox(height: 14),

                // Specialty autocomplete
                _sectionLabel('Specialty'),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  initialValue:
                      TextEditingValue(text: _specialtyCtrl.text),
                  optionsBuilder: (v) {
                    if (v.text.isEmpty) return _specialties;
                    return _specialties.where((s) =>
                        s.toLowerCase().contains(v.text.toLowerCase()));
                  },
                  onSelected: (v) => _specialtyCtrl.text = v,
                  fieldViewBuilder: (ctx, ctrl, focus, onSubmit) =>
                      TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    onFieldSubmitted: (_) => onSubmit(),
                    onChanged: (v) => _specialtyCtrl.text = v,
                    style: TextStyle(color: context.labelColor, fontSize: 14),
                    decoration: _dec(
                        'Specialty (e.g. General Practitioner)',
                        Icons.medical_services_rounded),
                  ),
                  optionsViewBuilder: (ctx, onSel, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      color: context.isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (_, i) {
                            final opt = options.elementAt(i);
                            return InkWell(
                              onTap: () => onSel(opt),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text(opt,
                                    style: TextStyle(
                                        color: context.labelColor,
                                        fontSize: 14)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Phone (required — used as login identifier)
                _field(_phoneCtrl, 'Phone Number *',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required for login' : null),
                const SizedBox(height: 14),

                // Hospital picker
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => HospitalPickerSheet(
                        selected: _selectedHospital,
                        onSelected: (h) =>
                            setState(() => _selectedHospital = h),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_hospital_rounded,
                            color: EnhancedTheme.accentPurple
                                .withValues(alpha: 0.8),
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedHospital?.displayName ??
                                'Select hospital / clinic',
                            style: TextStyle(
                              color: _selectedHospital != null
                                  ? context.labelColor
                                  : context.hintColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_selectedHospital != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedHospital = null),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: context.subLabelColor),
                          )
                        else
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: context.subLabelColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Address
                _field(_addressCtrl, 'Address',
                    icon: Icons.location_on_rounded, maxLines: 2),
                const SizedBox(height: 14),

                // Password
                _passwordField(
                  _passwordCtrl,
                  'Password *',
                  obscure: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Min 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                _passwordField(
                  _confirmPasswordCtrl,
                  'Confirm Password *',
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.accentPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Register as Prescriber',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          color: context.subLabelColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));

  Widget _field(
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(color: context.labelColor, fontSize: 14),
        decoration: _dec(label, icon),
      );

  Widget _passwordField(
    TextEditingController ctrl,
    String label, {
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        validator: validator,
        style: TextStyle(color: context.labelColor, fontSize: 14),
        decoration: _dec(label, Icons.lock_rounded).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: context.subLabelColor,
              size: 18,
            ),
            onPressed: onToggle,
          ),
        ),
      );

  InputDecoration _dec(String label, IconData? icon) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.subLabelColor, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.8),
                size: 18)
            : null,
        filled: true,
        fillColor: context.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: EnhancedTheme.accentPurple, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: EnhancedTheme.errorRed, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _SuccessDialog extends StatelessWidget {
  final String name;
  const _SuccessDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.successGreen.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: EnhancedTheme.successGreen, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Registration Submitted',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Welcome, $name!\nYour profile is under review. A pharmacy will link you once verified.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subLabelColor, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.successGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Continue to Login',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
