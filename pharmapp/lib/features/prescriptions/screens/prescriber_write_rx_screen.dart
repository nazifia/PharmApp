import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import '../providers/prescriber_provider.dart';

// ── Draft medication row ──────────────────────────────────────────────────────

class _MedRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController unit = TextEditingController(text: 'tab(s)');
  final TextEditingController dosage = TextEditingController();
  final TextEditingController duration = TextEditingController();
  final TextEditingController instructions = TextEditingController();

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    dosage.dispose();
    duration.dispose();
    instructions.dispose();
  }

  bool get isValid => name.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'item_name': name.text.trim(),
        'quantity': double.tryParse(quantity.text.trim()) ?? 1,
        'unit': unit.text.trim(),
        if (dosage.text.trim().isNotEmpty) 'dosage': dosage.text.trim(),
        if (duration.text.trim().isNotEmpty) 'duration': duration.text.trim(),
        if (instructions.text.trim().isNotEmpty)
          'instructions': instructions.text.trim(),
      };
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PrescriberWriteRxScreen extends ConsumerStatefulWidget {
  final Customer? patient;
  const PrescriberWriteRxScreen({super.key, this.patient});

  @override
  ConsumerState<PrescriberWriteRxScreen> createState() =>
      _PrescriberWriteRxScreenState();
}

class _PrescriberWriteRxScreenState
    extends ConsumerState<PrescriberWriteRxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_MedRow> _meds = [_MedRow()];
  Customer? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.patient;
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPatient == null) {
      _showError('Select a patient first');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final validMeds = _meds.where((m) => m.isValid).toList();
    if (validMeds.isEmpty) {
      _showError('Add at least one medication');
      return;
    }

    final prescriber = ref.read(currentPrescriberProvider);
    final data = <String, dynamic>{
      'customer': _selectedPatient!.id,
      if (prescriber != null) 'prescriber_id': prescriber.id,
      if (_diagnosisCtrl.text.trim().isNotEmpty)
        'diagnosis': _diagnosisCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
      'items': validMeds.map((m) => m.toMap()).toList(),
    };

    final ok = await ref
        .read(prescriberPatientNotifierProvider.notifier)
        .submitPrescription(data);

    if (!mounted) return;

    if (ok) {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _SuccessDialog(patientName: _selectedPatient!.name),
      );
      if (mounted) Navigator.pop(context);
    } else {
      final err = ref.read(prescriberPatientNotifierProvider).error;
      _showError('$err');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: EnhancedTheme.errorRed,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(prescriberPatientNotifierProvider).isLoading;
    final prescriber = ref.watch(currentPrescriberProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      children: [
                        // Prescriber chip
                        if (prescriber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.accentPurple
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: EnhancedTheme.accentPurple
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.medical_services_rounded,
                                    color: EnhancedTheme.accentPurple,
                                    size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dr. ${prescriber.name}'
                                    '${prescriber.specialty != null ? ' · ${prescriber.specialty}' : ''}',
                                    style: const TextStyle(
                                        color:
                                            EnhancedTheme.accentPurple,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Patient
                        _SectionCard(
                          title: 'Patient',
                          child: _PatientPicker(
                            selected: _selectedPatient,
                            onSelected: (c) =>
                                setState(() => _selectedPatient = c),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Diagnosis
                        _SectionCard(
                          title: 'Diagnosis',
                          child: TextFormField(
                            controller: _diagnosisCtrl,
                            maxLines: 2,
                            style: TextStyle(
                                color: context.labelColor,
                                fontSize: 14),
                            decoration: _plainDec(context,
                                'Diagnosis / clinical impression'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Medications
                        _SectionCard(
                          title: 'Medications',
                          trailing: TextButton.icon(
                            onPressed: () =>
                                setState(() => _meds.add(_MedRow())),
                            icon: const Icon(Icons.add_rounded,
                                size: 16),
                            label: const Text('Add',
                                style: TextStyle(fontSize: 13)),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  EnhancedTheme.accentPurple,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          child: Column(
                            children: _meds
                                .asMap()
                                .entries
                                .map((e) => _MedRowWidget(
                                      index: e.key,
                                      row: e.value,
                                      canRemove: _meds.length > 1,
                                      onRemove: () => setState(() {
                                        e.value.dispose();
                                        _meds.removeAt(e.key);
                                      }),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notes
                        _SectionCard(
                          title: 'Notes',
                          child: TextFormField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            style: TextStyle(
                                color: context.labelColor,
                                fontSize: 14),
                            decoration: _plainDec(context,
                                'Additional notes / instructions for pharmacist'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  EnhancedTheme.accentPurple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5))
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text('Submit Prescription',
                                          style: GoogleFonts.outfit(
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 16)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildHeader(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Write Prescription',
              style: GoogleFonts.outfit(
                  color: context.labelColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

InputDecoration _plainDec(BuildContext context, String hint) =>
    InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: context.hintColor, fontSize: 13),
      filled: true,
      fillColor: context.isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.03),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: EnhancedTheme.accentPurple, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: context.borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                        color: context.subLabelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8),
                  ),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Patient picker ────────────────────────────────────────────────────────────

class _PatientPicker extends ConsumerWidget {
  final Customer? selected;
  final ValueChanged<Customer?> onSelected;

  const _PatientPicker(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(prescriberPatientListProvider);

    return patients.when(
      data: (list) {
        if (selected != null) return _chip(context, selected!);
        if (list.isEmpty) {
          return Text(
            'No patients registered yet. Go to My Patients and add a patient first.',
            style: TextStyle(color: context.subLabelColor, fontSize: 13),
          );
        }
        return DropdownButtonFormField<Customer>(
          initialValue: selected,
          hint: Text('Select patient',
              style:
                  TextStyle(color: context.hintColor, fontSize: 14)),
          onChanged: onSelected,
          items: list
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.name} · ${c.phone}',
                        style: TextStyle(
                            color: context.labelColor,
                            fontSize: 14)),
                  ))
              .toList(),
          dropdownColor: context.isDark
              ? const Color(0xFF1E293B)
              : Colors.white,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_rounded,
                color: EnhancedTheme.accentPurple, size: 18),
            filled: true,
            fillColor: context.isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: EnhancedTheme.accentPurple, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load patients: $e',
          style: const TextStyle(
              color: EnhancedTheme.errorRed, fontSize: 13)),
    );
  }

  Widget _chip(BuildContext context, Customer patient) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  EnhancedTheme.accentPurple.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                patient.name.isNotEmpty
                    ? patient.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: EnhancedTheme.accentPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name,
                    style: TextStyle(
                        color: context.labelColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(patient.phone,
                    style: TextStyle(
                        color: context.subLabelColor,
                        fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onSelected(null),
            child: Icon(Icons.close_rounded,
                size: 18, color: context.subLabelColor),
          ),
        ],
      );
}

// ── Medication row widget ─────────────────────────────────────────────────────

class _MedRowWidget extends StatelessWidget {
  final int index;
  final _MedRow row;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MedRowWidget({
    required this.index,
    required this.row,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0)
          Divider(color: context.borderColor, height: 24),
        Row(
          children: [
            Text('Medication ${index + 1}',
                style: TextStyle(
                    color: context.subLabelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (canRemove)
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.remove_circle_outline_rounded,
                    color: EnhancedTheme.errorRed
                        .withValues(alpha: 0.7),
                    size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _tf(context, row.name, 'Drug name *',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _tf(context, row.quantity, 'Qty',
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _tf(context, row.unit, 'Unit')),
          ],
        ),
        const SizedBox(height: 8),
        _tf(context, row.dosage, 'Dosage (e.g. 1 twice daily)'),
        const SizedBox(height: 8),
        _tf(context, row.duration, 'Duration (e.g. 7 days)'),
        const SizedBox(height: 8),
        _tf(context, row.instructions, 'Special instructions'),
      ],
    );
  }

  Widget _tf(
    BuildContext context,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: context.labelColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: context.hintColor, fontSize: 12),
          filled: true,
          fillColor: context.isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: EnhancedTheme.accentPurple, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: EnhancedTheme.errorRed, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 10),
        ),
      );
}

// ── Success dialog ────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final String patientName;
  const _SuccessDialog({required this.patientName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          context.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.successGreen
                    .withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: EnhancedTheme.successGreen, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Prescription Sent',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Prescription for $patientName has been submitted successfully.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: context.subLabelColor, fontSize: 13),
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
                child: const Text('Done',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
