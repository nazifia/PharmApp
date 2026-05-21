import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import '../providers/prescriber_provider.dart';
import 'prescriber_write_rx_screen.dart';

class PrescriberPatientsScreen extends ConsumerStatefulWidget {
  const PrescriberPatientsScreen({super.key});

  @override
  ConsumerState<PrescriberPatientsScreen> createState() =>
      _PrescriberPatientsScreenState();
}

class _PrescriberPatientsScreenState
    extends ConsumerState<PrescriberPatientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(prescriberPatientListProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearch(context),
                Expanded(
                  child: patients.when(
                    data: (list) {
                      final filtered = _search.isEmpty
                          ? list
                          : list
                              .where((c) =>
                                  c.name
                                      .toLowerCase()
                                      .contains(_search.toLowerCase()) ||
                                  c.phone.contains(_search))
                              .toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  color: context.subLabelColor, size: 52),
                              const SizedBox(height: 12),
                              Text(
                                _search.isEmpty
                                    ? 'No patients registered yet'
                                    : 'No patients found',
                                style: TextStyle(color: context.subLabelColor),
                              ),
                              if (_search.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + Add Patient to register your first patient',
                                  style: TextStyle(
                                      color: context.subLabelColor,
                                      fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _PatientCard(
                          patient: filtered[i],
                          onWriteRx: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrescriberWriteRxScreen(
                                  patient: filtered[i]),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: EnhancedTheme.errorRed, size: 40),
                          const SizedBox(height: 12),
                          Text('$e',
                              style:
                                  TextStyle(color: context.subLabelColor),
                              textAlign: TextAlign.center),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(prescriberPatientListProvider),
                            child: const Text('Retry'),
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRegisterSheet(context),
        backgroundColor: EnhancedTheme.accentPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Patient'),
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
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Patients',
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  Text('Register and manage patient records',
                      style: TextStyle(
                          color: context.subLabelColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildSearch(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search patients...',
            hintStyle:
                TextStyle(color: context.hintColor, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: EnhancedTheme.accentPurple, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      );

  void _showRegisterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegisterPatientSheet(
        onSuccess: () => ref.invalidate(prescriberPatientListProvider),
      ),
    );
  }
}

// ── Patient card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Customer patient;
  final VoidCallback onWriteRx;

  const _PatientCard({required this.patient, required this.onWriteRx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
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
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EnhancedTheme.accentPurple
                        .withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      patient.name.isNotEmpty
                          ? patient.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: EnhancedTheme.accentPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name,
                          style: TextStyle(
                              color: context.labelColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(patient.phone,
                          style: TextStyle(
                              color: context.subLabelColor,
                              fontSize: 13)),
                      if (patient.dateOfBirth != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'DOB: ${DateFormat('dd MMM yyyy').format(patient.dateOfBirth!)}',
                          style: TextStyle(
                              color: context.subLabelColor,
                              fontSize: 12),
                        ),
                      ],
                      if (patient.bloodGroup != null)
                        Text('Blood: ${patient.bloodGroup}',
                            style: TextStyle(
                                color: context.subLabelColor,
                                fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onWriteRx,
                  icon: const Icon(Icons.edit_document, size: 14),
                  label: const Text('Write Rx',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EnhancedTheme.accentPurple,
                    side: BorderSide(
                        color: EnhancedTheme.accentPurple
                            .withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Register patient bottom sheet ─────────────────────────────────────────────

class _RegisterPatientSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _RegisterPatientSheet({required this.onSuccess});

  @override
  ConsumerState<_RegisterPatientSheet> createState() =>
      _RegisterPatientSheetState();
}

class _RegisterPatientSheetState
    extends ConsumerState<_RegisterPatientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  String? _bloodGroup;
  DateTime? _dob;

  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  List<String> _splitComma(String s) => s
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'is_network_patient': true,
      'is_wholesale': false,
      if (_emailCtrl.text.trim().isNotEmpty)
        'email': _emailCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty)
        'address': _addressCtrl.text.trim(),
      if (_bloodGroup != null) 'blood_group': _bloodGroup,
      if (_dob != null)
        'date_of_birth':
            '${_dob!.year.toString().padLeft(4, '0')}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}',
      if (_allergiesCtrl.text.trim().isNotEmpty)
        'allergies': _splitComma(_allergiesCtrl.text),
      if (_conditionsCtrl.text.trim().isNotEmpty)
        'chronic_conditions': _splitComma(_conditionsCtrl.text),
    };

    final result = await ref
        .read(prescriberPatientNotifierProvider.notifier)
        .registerPatient(data);

    if (!mounted) return;

    final state = ref.read(prescriberPatientNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: ${state.error}'),
        backgroundColor: EnhancedTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (result != null) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${result.name} registered successfully'),
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(prescriberPatientNotifierProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.person_add_rounded,
                      color: EnhancedTheme.accentPurple, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Register Patient',
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  children: [
                    _field(_nameCtrl, 'Full Name *',
                        icon: Icons.person_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null),
                    const SizedBox(height: 12),
                    _field(_phoneCtrl, 'Phone Number *',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null),
                    const SizedBox(height: 12),
                    _field(_emailCtrl, 'Email (optional)',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _field(_addressCtrl, 'Address (optional)',
                        icon: Icons.location_on_rounded, maxLines: 2),
                    const SizedBox(height: 12),
                    // DOB picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1990),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _dob = picked);
                      },
                      child: _fieldLike(
                        icon: Icons.cake_rounded,
                        label: _dob != null
                            ? 'DOB: ${DateFormat('dd MMM yyyy').format(_dob!)}'
                            : 'Date of Birth (optional)',
                        isHint: _dob == null,
                        trailing: _dob != null
                            ? GestureDetector(
                                onTap: () =>
                                    setState(() => _dob = null),
                                child: Icon(Icons.close_rounded,
                                    size: 16,
                                    color: context.subLabelColor),
                              )
                            : Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: context.subLabelColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _bloodGroup,
                      onChanged: (v) =>
                          setState(() => _bloodGroup = v),
                      items: _bloodGroups
                          .map((g) => DropdownMenuItem(
                              value: g, child: Text(g)))
                          .toList(),
                      dropdownColor: context.isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      style: TextStyle(
                          color: context.labelColor, fontSize: 14),
                      decoration: _dec(
                          'Blood Group (optional)',
                          Icons.bloodtype_rounded),
                    ),
                    const SizedBox(height: 12),
                    _field(_allergiesCtrl,
                        'Known Allergies (comma-separated)',
                        icon: Icons.warning_amber_rounded),
                    const SizedBox(height: 12),
                    _field(_conditionsCtrl,
                        'Chronic Conditions (comma-separated)',
                        icon: Icons.monitor_heart_rounded),
                    const SizedBox(height: 24),
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
                            : Text('Register Patient',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _fieldLike({
    required IconData icon,
    required String label,
    bool isHint = false,
    Widget? trailing,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    EnhancedTheme.accentPurple.withValues(alpha: 0.8),
                size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      isHint ? context.hintColor : context.labelColor,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  InputDecoration _dec(String label, IconData? icon) =>
      InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: context.subLabelColor, fontSize: 13),
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
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      );
}
