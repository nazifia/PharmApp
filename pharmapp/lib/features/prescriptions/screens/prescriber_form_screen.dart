import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/prescriber.dart';
import '../providers/prescriber_provider.dart';

/// Bottom-sheet form for adding or editing a prescriber.
/// Pass [existing] to enter edit mode.
class PrescriberFormSheet extends ConsumerStatefulWidget {
  final Prescriber? existing;
  const PrescriberFormSheet({super.key, this.existing});

  @override
  ConsumerState<PrescriberFormSheet> createState() =>
      _PrescriberFormSheetState();
}

class _PrescriberFormSheetState extends ConsumerState<PrescriberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _specialtyCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _clinicCtrl;
  late final TextEditingController _addressCtrl;
  late bool _networkShared;
  bool _saving = false;

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
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _licenseCtrl = TextEditingController(text: p?.licenseNumber ?? '');
    _specialtyCtrl = TextEditingController(text: p?.specialty ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _clinicCtrl = TextEditingController(text: p?.clinic ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _networkShared = p?.isNetworkShared ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _specialtyCtrl.dispose();
    _phoneCtrl.dispose();
    _clinicCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      if (_licenseCtrl.text.trim().isNotEmpty)
        'license_number': _licenseCtrl.text.trim(),
      if (_specialtyCtrl.text.trim().isNotEmpty)
        'specialty': _specialtyCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_clinicCtrl.text.trim().isNotEmpty) 'clinic': _clinicCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty)
        'address': _addressCtrl.text.trim(),
      'is_network_shared': _networkShared,
    };

    final notifier = ref.read(prescriberNotifierProvider.notifier);
    Prescriber? result;
    if (widget.existing != null) {
      result = await notifier.updatePrescriber(widget.existing!.id, data);
    } else {
      result = await notifier.createPrescriber(data);
    }

    setState(() => _saving = false);
    if (!mounted) return;

    final state = ref.read(prescriberNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
        'Error: ${state.error}',
        EnhancedTheme.errorRed,
        Colors.white,
      ));
    } else if (result != null) {
      Navigator.of(context).pop(result);
      ScaffoldMessenger.of(context).showSnackBar(_snack(
        widget.existing == null
            ? '${result.name} added successfully'
            : '${result.name} updated',
        EnhancedTheme.successGreen,
        Colors.white,
      ));
    }
  }

  SnackBar _snack(String msg, Color bg, Color fg) => SnackBar(
        backgroundColor: bg.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                  top: BorderSide(
                      color: EnhancedTheme.accentPurple.withValues(alpha: 0.4),
                      width: 1.5)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color:
                              EnhancedTheme.accentPurple.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit
                              ? Icons.edit_rounded
                              : Icons.person_add_rounded,
                          color: EnhancedTheme.accentPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEdit ? 'Edit Prescriber' : 'Add Prescriber',
                        style: GoogleFonts.outfit(
                            color: context.labelColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Text(
                        'Doctor or licensed prescriber details',
                        style: TextStyle(
                            color: context.subLabelColor, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    _field(_nameCtrl, 'Full Name *',
                        icon: Icons.person_rounded,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 14),

                    // License number
                    _field(_licenseCtrl, 'License / Registration Number',
                        icon: Icons.badge_rounded),
                    const SizedBox(height: 14),

                    // Specialty autocomplete
                    _label('Specialty'),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(
                          text: _specialtyCtrl.text),
                      optionsBuilder: (v) {
                        if (v.text.isEmpty) return _specialties;
                        return _specialties.where((s) => s
                            .toLowerCase()
                            .contains(v.text.toLowerCase()));
                      },
                      onSelected: (v) => _specialtyCtrl.text = v,
                      fieldViewBuilder:
                          (ctx, ctrl, focus, onSubmit) => TextFormField(
                        controller: ctrl,
                        focusNode: focus,
                        onFieldSubmitted: (_) => onSubmit(),
                        onChanged: (v) => _specialtyCtrl.text = v,
                        style: TextStyle(
                            color: context.labelColor, fontSize: 14),
                        decoration: _inputDec(
                            'Specialty (e.g. General Practitioner)',
                            Icons.medical_services_rounded,
                            context),
                      ),
                      optionsViewBuilder: (ctx, onSel, options) =>
                          Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: context.isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 200),
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

                    // Phone
                    _field(_phoneCtrl, 'Phone Number',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),

                    // Clinic / Hospital
                    _field(_clinicCtrl, 'Clinic / Hospital Name',
                        icon: Icons.local_hospital_rounded),
                    const SizedBox(height: 14),

                    // Address
                    _field(_addressCtrl, 'Address',
                        icon: Icons.location_on_rounded, maxLines: 2),
                    const SizedBox(height: 20),

                    // Network shared toggle
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _networkShared
                            ? EnhancedTheme.accentCyan.withValues(alpha: 0.08)
                            : context.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _networkShared
                              ? EnhancedTheme.accentCyan
                                  .withValues(alpha: 0.4)
                              : context.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded,
                              color: _networkShared
                                  ? EnhancedTheme.accentCyan
                                  : context.subLabelColor,
                              size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Share across network',
                                    style: TextStyle(
                                        color: context.labelColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  'Visible to all pharmacies in your network',
                                  style: TextStyle(
                                      color: context.subLabelColor,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _networkShared,
                            onChanged: (v) =>
                                setState(() => _networkShared = v),
                            activeTrackColor: EnhancedTheme.accentCyan,
                            activeThumbColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                isEdit ? 'Save Changes' : 'Add Prescriber',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
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
        decoration: _inputDec(label, icon, context),
      );

  InputDecoration _inputDec(String label, IconData? icon, BuildContext ctx) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ctx.subLabelColor, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: EnhancedTheme.accentPurple, size: 18)
            : null,
        filled: true,
        fillColor: ctx.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ctx.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ctx.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: EnhancedTheme.accentPurple, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: EnhancedTheme.errorRed, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
