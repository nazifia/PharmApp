import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import '../providers/prescription_provider.dart';
import '../providers/prescriber_provider.dart';
import '../../../shared/models/prescription.dart';
import '../../../shared/models/prescriber.dart';
import '../../../features/branches/providers/branch_provider.dart';
import '../../../features/customers/providers/customer_provider.dart';
import '../../../core/services/drug_interaction_service.dart';
import 'prescriber_form_screen.dart';

// ── Draft medication row ──────────────────────────────────────────────────────

class _DraftMed {
  final TextEditingController name;
  final TextEditingController brand;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController dosage;
  final TextEditingController duration;
  final TextEditingController instructions;
  int? itemId;

  _DraftMed()
      : name = TextEditingController(),
        brand = TextEditingController(),
        quantity = TextEditingController(text: '1'),
        unit = TextEditingController(text: 'tab(s)'),
        dosage = TextEditingController(),
        duration = TextEditingController(),
        instructions = TextEditingController();

  void dispose() {
    name.dispose();
    brand.dispose();
    quantity.dispose();
    unit.dispose();
    dosage.dispose();
    duration.dispose();
    instructions.dispose();
  }

  PrescriptionItem toItem() => PrescriptionItem(
        itemId: itemId,
        itemName: name.text.trim(),
        brand: brand.text.trim().isNotEmpty ? brand.text.trim() : null,
        quantity: double.tryParse(quantity.text.trim()) ?? 1,
        unit: unit.text.trim().isNotEmpty ? unit.text.trim() : 'unit(s)',
        dosage: dosage.text.trim().isNotEmpty ? dosage.text.trim() : null,
        duration: duration.text.trim().isNotEmpty ? duration.text.trim() : null,
        instructions: instructions.text.trim().isNotEmpty
            ? instructions.text.trim()
            : null,
      );

  bool get isValid => name.text.trim().isNotEmpty;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WritePrescriptionScreen extends ConsumerStatefulWidget {
  const WritePrescriptionScreen({super.key});

  @override
  ConsumerState<WritePrescriptionScreen> createState() =>
      _WritePrescriptionScreenState();
}

class _WritePrescriptionScreenState
    extends ConsumerState<WritePrescriptionScreen> {
  // Step: 0 = find patient, 1 = write rx
  int _step = 0;

  // Customer search state
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchGlobal = false;
  GlobalCustomerSearchResult? _selectedPatient;
  // Manual walk-in fields
  final _walkInNameCtrl = TextEditingController();
  final _walkInPhoneCtrl = TextEditingController();

  // Prescription fields
  final _doctorCtrl = TextEditingController(); // free-text fallback
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _refillsAllowed = 0;
  final List<_DraftMed> _medications = [];
  final _formKey = GlobalKey<FormState>();

  // Prescriber picker state
  Prescriber? _selectedPrescriber;
  final _prescriberSearchCtrl = TextEditingController();
  String _prescriberQuery = '';

  // Consultation fee category (A–E) — derived from the selected prescriber's bands
  String? _consultCategory;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _medications.add(_DraftMed()); // start with one empty row
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _walkInNameCtrl.dispose();
    _walkInPhoneCtrl.dispose();
    _doctorCtrl.dispose();
    _prescriberSearchCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    for (final m in _medications) {
      m.dispose();
    }
    super.dispose();
  }

  Widget _buildRefillsSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  size: 17, color: Colors.black45),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Refills Allowed',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _refillsAllowed > 0
                          ? () => setState(() => _refillsAllowed--)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.remove_rounded,
                            size: 16,
                            color: _refillsAllowed > 0
                                ? EnhancedTheme.primaryTeal
                                : Colors.black26),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$_refillsAllowed',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    GestureDetector(
                      onTap: _refillsAllowed < 12
                          ? () => setState(() => _refillsAllowed++)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.add_rounded,
                            size: 16,
                            color: _refillsAllowed < 12
                                ? EnhancedTheme.primaryTeal
                                : Colors.black26),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Number of times this prescription can be refilled (0–12)',
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Search provider key ─────────────────────────────────────────────────────

  String get _effectiveQuery =>
      _searchQuery.trim().length >= 2 ? _searchQuery.trim() : '';

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _proceedWithPatient(GlobalCustomerSearchResult patient) {
    setState(() {
      _selectedPatient = patient;
      _step = 1;
    });
  }

  void _proceedAsWalkIn() {
    final name = _walkInNameCtrl.text.trim();
    final phone = _walkInPhoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
        'Enter patient name to continue.',
        EnhancedTheme.warningAmber,
        Colors.black,
      ));
      return;
    }
    setState(() {
      _selectedPatient = GlobalCustomerSearchResult(
        name: name,
        phone: phone,
      );
      _step = 1;
    });
  }

  // ── Drug interaction check ──────────────────────────────────────────────────

  Future<List<DrugWarning>> _gatherWarnings(List<String> drugNames) async {
    final patient = _selectedPatient;
    final allWarnings = <DrugWarning>[];

    // Cross-check drugs within this prescription against each other.
    final valid = drugNames.where((d) => d.trim().isNotEmpty).toList();
    for (int i = 0; i < valid.length; i++) {
      for (int j = i + 1; j < valid.length; j++) {
        allWarnings.addAll(DrugInteractionService.checkInteractions(
          valid[i],
          [valid[j]],
          const [],
        ));
      }
    }

    if (patient == null || patient.id == null || patient.id! <= 0) return allWarnings;
    try {
      final customer = await ref.read(customerDetailProvider(patient.id!).future);
      for (final drug in valid) {
        allWarnings.addAll(DrugInteractionService.checkInteractions(
          drug,
          customer.currentMedications,
          customer.allergies,
        ));
      }
    } catch (_) {}

    return allWarnings;
  }

  Future<bool> _showWarningDialog(List<DrugWarning> warnings) async {
    final hasAllergy = warnings.any((w) => w.severity == WarningSeverity.allergy);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: hasAllergy
                ? EnhancedTheme.errorRed.withValues(alpha: 0.15)
                : EnhancedTheme.accentOrange.withValues(alpha: 0.12),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(
                hasAllergy
                    ? Icons.warning_rounded
                    : Icons.error_rounded,
                color: hasAllergy
                    ? EnhancedTheme.errorRed
                    : EnhancedTheme.accentOrange,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Drug Safety Warning',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                ...warnings.map((w) {
                  final color = DrugInteractionService.severityColor(w.severity);
                  final icon = DrugInteractionService.severityIcon(w.severity);
                  final label = DrugInteractionService.severityLabel(w.severity);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                w.message,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasAllergy
                  ? EnhancedTheme.errorRed
                  : EnhancedTheme.accentOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Override & Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final validMeds =
        _medications.where((m) => m.isValid).map((m) => m.toItem()).toList();
    if (validMeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
        'Add at least one medication.',
        EnhancedTheme.warningAmber,
        Colors.black,
      ));
      return;
    }

    final drugNames = validMeds.map((m) => m.itemName).toList();
    final warnings = await _gatherWarnings(drugNames);
    if (!mounted) return;
    if (warnings.isNotEmpty) {
      final proceed = await _showWarningDialog(warnings);
      if (!mounted) return;
      if (!proceed) return;
    }

    setState(() => _isSubmitting = true);

    final patient = _selectedPatient!;
    final branch = ref.read(activeBranchProvider);
    final payload = {
      if (patient.id != null && patient.id! > 0) 'customer_id': patient.id,
      'customer_name': patient.name,
      'customer_phone': patient.phone,
      if (patient.pharmacyId != null) 'source_pharmacy_id': patient.pharmacyId,
      if (_selectedPrescriber != null) ...{
        'prescriber_id': _selectedPrescriber!.id,
        'doctor_name': _selectedPrescriber!.name,
      } else if (_doctorCtrl.text.trim().isNotEmpty)
        'doctor_name': _doctorCtrl.text.trim(),
      if (_diagnosisCtrl.text.trim().isNotEmpty)
        'diagnosis': _diagnosisCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      if (_consultCategory != null) 'consultation_category': _consultCategory,
      'medications': validMeds.map((m) => m.toJson()).toList(),
      if (branch != null && branch.id > 0) 'branch_id': branch.id,
      'refills_allowed': _refillsAllowed,
    };

    final result = await ref
        .read(prescriptionNotifierProvider.notifier)
        .createPrescription(payload);

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
        'Prescription saved successfully.',
        EnhancedTheme.successGreen,
        Colors.white,
      ));
      context.pop();
    } else {
      final notifierState = ref.read(prescriptionNotifierProvider);
      if (notifierState is AsyncError) {
        final msg = notifierState.error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          msg,
          EnhancedTheme.errorRed,
          Colors.white,
        ));
      } else {
        // queued offline
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          'Saved offline — will sync when connected.',
          EnhancedTheme.warningAmber,
          Colors.black,
        ));
        context.pop();
      }
    }
  }

  List<String> _consultCats(Prescriber p) => const ['A', 'B', 'C', 'D', 'E']
      .where((c) => (p.consultationFees[c] ?? 0) > 0)
      .toList();

  Widget _buildConsultPicker() {
    final p = _selectedPrescriber!;
    final cats = _consultCats(p);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.medical_information_rounded,
                size: 17, color: Colors.black45),
            SizedBox(width: 8),
            Expanded(
              child: Text('Consultation Fee',
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Added at payment, not shown on the receipt.',
              style: TextStyle(color: Colors.black38, fontSize: 11)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                GestureDetector(
                  onTap: () => setState(
                      () => _consultCategory = _consultCategory == c ? null : c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _consultCategory == c
                          ? EnhancedTheme.accentPurple.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _consultCategory == c
                            ? EnhancedTheme.accentPurple
                            : Colors.black.withValues(alpha: 0.12),
                        width: _consultCategory == c ? 1.5 : 1,
                      ),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Cat $c',
                          style: TextStyle(
                              color: _consultCategory == c
                                  ? EnhancedTheme.accentPurple
                                  : Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(fmtN(p.consultationFees[c] ?? 0),
                          style: TextStyle(
                              color: _consultCategory == c
                                  ? EnhancedTheme.accentPurple
                                  : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  SnackBar _snack(String msg, Color bg, Color fg) => SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text(msg,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      );

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) {
          setState(() {
            _step = 0;
            _selectedPatient = null;
          });
        }
      },
      child: Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                // Custom header (replaces AppBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_step == 1) {
                            setState(() {
                              _step = 0;
                              _selectedPatient = null;
                            });
                          } else {
                            context.pop();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white70, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _step == 0 ? 'Find Patient' : 'Write Prescription',
                          style: TextStyle(
                              color: context.labelColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                _StepIndicator(step: _step),
                // Body content
                Expanded(
                  child: _step == 0 ? _patientSearchStep() : _rxWriteStep(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Step 0: Patient search ─────────────────────────────────────────────────

  Widget _patientSearchStep() {
    final searchAsync = _effectiveQuery.isNotEmpty
        ? ref.watch(globalCustomerSearchProvider(_effectiveQuery))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search by name or phone number…',
              hintStyle: const TextStyle(
                  color: Colors.black38, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Colors.black45, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: EnhancedTheme.primaryTeal),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 10),
          // Global toggle
          Row(
            children: [
              Switch(
                value: _searchGlobal,
                onChanged: (v) => setState(() => _searchGlobal = v),
                activeTrackColor: EnhancedTheme.primaryTeal,
                activeThumbColor: Colors.white,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Search across all pharmacies',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(
                      'Find patients registered in any subscribed pharmacy',
                      style: TextStyle(
                          color: Colors.black45,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search results
          if (searchAsync != null)
            searchAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: EnhancedTheme.primaryTeal),
              )),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e',
                    style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 13)),
              ),
              data: (results) {
                final filtered = _searchGlobal
                    ? results
                    : results.where((r) => r.pharmacyId == null).toList();
                if (filtered.isEmpty) {
                  return _NoResultsView(
                    query: _effectiveQuery,
                    onWalkIn: () => _showWalkInSheet(),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ...filtered.asMap().entries.map((e) => _CustomerResultTile(
                          result: e.value,
                          onTap: () => _proceedWithPatient(e.value),
                        ).animate().fadeIn(
                            delay: Duration(milliseconds: e.key * 40))),
                  ],
                );
              },
            )
          else ...[
            // Initial hint
            const _HintCard(
              icon: Icons.phone_rounded,
              text: 'Enter a phone number to search',
            ),
            const SizedBox(height: 8),
            const _HintCard(
              icon: Icons.person_search_rounded,
              text: 'Or search by patient name',
            ),
          ],
          const SizedBox(height: 24),

          // Walk-in section
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          const Text('Walk-in Patient',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Patient not in system? Enter details manually.',
              style: TextStyle(
                  color: Colors.black45, fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showWalkInSheet,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Continue as Walk-in'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.05),
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showWalkInSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Walk-in Patient Details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DarkTextField(
              controller: _walkInNameCtrl,
              label: 'Patient Name *',
              icon: Icons.person_rounded,
              isOnDark: true,
            ),
            const SizedBox(height: 12),
            _DarkTextField(
              controller: _walkInPhoneCtrl,
              label: 'Phone Number (optional)',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              isOnDark: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _proceedAsWalkIn();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Continue',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Rx form ─────────────────────────────────────────────────────────

  Widget _rxWriteStep() {
    final patient = _selectedPatient!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Patient summary
          _SelectedPatientBanner(
            patient: patient,
            onChange: () => setState(() {
              _step = 0;
              _selectedPatient = null;
            }),
          ),
          const SizedBox(height: 16),

          // Doctor / Prescriber / Diagnosis / Notes
          const _SectionLabel('Prescription Info'),
          const SizedBox(height: 8),
          _PrescriberPickerField(
            selected: _selectedPrescriber,
            searchCtrl: _prescriberSearchCtrl,
            query: _prescriberQuery,
            freeTextCtrl: _doctorCtrl,
            onQueryChanged: (v) => setState(() => _prescriberQuery = v),
            onSelected: (p) => setState(() {
              _selectedPrescriber = p;
              _consultCategory = null;
              _prescriberSearchCtrl.clear();
              _prescriberQuery = '';
            }),
            onClear: () => setState(() {
              _selectedPrescriber = null;
              _consultCategory = null;
              _prescriberSearchCtrl.clear();
              _prescriberQuery = '';
            }),
            onAddNew: () async {
              final result = await showModalBottomSheet<Prescriber>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const PrescriberFormSheet(),
              );
              if (result != null && mounted) {
                setState(() => _selectedPrescriber = result);
              }
            },
          ),
          if (_selectedPrescriber != null &&
              _consultCats(_selectedPrescriber!).isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildConsultPicker(),
          ],
          const SizedBox(height: 10),
          _DarkTextField(
            controller: _diagnosisCtrl,
            label: 'Diagnosis / Condition (optional)',
            icon: Icons.local_hospital_rounded,
          ),
          const SizedBox(height: 10),
          _DarkTextField(
            controller: _notesCtrl,
            label: 'Additional Notes (optional)',
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          _buildRefillsSelector(),
          const SizedBox(height: 20),

          // Medications
          Row(
            children: [
              const Expanded(
                child: _SectionLabel('Medications'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _medications.add(_DraftMed())),
                icon: const Icon(Icons.add_rounded, size: 18,
                    color: EnhancedTheme.primaryTeal),
                label: const Text('Add',
                    style: TextStyle(color: EnhancedTheme.primaryTeal,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),

          ..._medications.asMap().entries.map((entry) {
            final i = entry.key;
            final med = entry.value;
            return _MedicationFormCard(
              index: i,
              med: med,
              canRemove: _medications.length > 1,
              onRemove: () => setState(() {
                med.dispose();
                _medications.removeAt(i);
              }),
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: i * 40))
                .slideY(begin: 0.05, end: 0);
          }),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _medications.add(_DraftMed())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add another medication'),
            style: OutlinedButton.styleFrom(
              foregroundColor: EnhancedTheme.primaryTeal,
              side:
                  BorderSide(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.primaryTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Prescription',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            color: EnhancedTheme.primaryTeal,
          ),
        ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            color: step >= 1
                ? EnhancedTheme.primaryTeal
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

// ── Selected patient banner ───────────────────────────────────────────────────

class _SelectedPatientBanner extends StatelessWidget {
  final GlobalCustomerSearchResult patient;
  final VoidCallback onChange;

  const _SelectedPatientBanner({required this.patient, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_rounded,
                color: EnhancedTheme.primaryTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                if (patient.phone.isNotEmpty)
                  Text(patient.phone,
                      style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12)),
                if (patient.pharmacyName != null)
                  Text('From ${patient.pharmacyName}',
                      style: TextStyle(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.8),
                          fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text('Change',
                style: TextStyle(
                    color: EnhancedTheme.primaryTeal, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Customer search result tile ───────────────────────────────────────────────

class _CustomerResultTile extends StatelessWidget {
  final GlobalCustomerSearchResult result;
  final VoidCallback onTap;

  const _CustomerResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_rounded,
                  color: EnhancedTheme.accentCyan, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.name,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  if (result.phone.isNotEmpty)
                    Text(result.phone,
                        style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12)),
                  if (result.pharmacyName != null &&
                      result.pharmacyName!.isNotEmpty)
                    Text('📍 ${result.pharmacyName}',
                        style: TextStyle(
                            color: EnhancedTheme.accentCyan.withValues(alpha: 0.7),
                            fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.black38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Medication form card ──────────────────────────────────────────────────────

class _MedicationFormCard extends StatelessWidget {
  final int index;
  final _DraftMed med;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MedicationFormCard({
    required this.index,
    required this.med,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Medication ${index + 1}',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: EnhancedTheme.errorRed, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: med.name,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name required' : null,
            decoration: _fieldDeco(
                'Drug/Medication Name *', Icons.medication_rounded),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: med.brand,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  decoration: _fieldDeco('Brand (optional)', null),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: med.quantity,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  keyboardType: TextInputType.number,
                  decoration: _fieldDeco('Qty', null),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: med.unit,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  decoration: _fieldDeco('Unit', null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: med.dosage,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  decoration: _fieldDeco('Dosage (e.g. twice daily)', null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: med.duration,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  decoration: _fieldDeco('Duration (e.g. 7 days)', null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: med.instructions,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            maxLines: 2,
            decoration: _fieldDeco(
                'Special instructions (optional)', Icons.notes_rounded),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco(String label, IconData? icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: Colors.black45, fontSize: 12),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.black38, size: 18)
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: EnhancedTheme.errorRed),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w700));
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;
  final bool isOnDark;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.isOnDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isOnDark ? Colors.white : Colors.black87;
    final labelColor = isOnDark ? Colors.white54 : Colors.black45;
    final iconColor = isOnDark ? Colors.white38 : Colors.black38;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontSize: 13),
        prefixIcon: Icon(icon, color: iconColor, size: 19),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 18),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  final String query;
  final VoidCallback onWalkIn;

  const _NoResultsView({required this.query, required this.onWalkIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.person_search_rounded,
            size: 48, color: Colors.black26),
        const SizedBox(height: 12),
        Text('No patients found for "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.black45, fontSize: 14)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onWalkIn,
          child: const Text('Continue as walk-in patient →',
              style: TextStyle(color: EnhancedTheme.accentCyan)),
        ),
      ],
    );
  }
}

// ── Prescriber picker field ───────────────────────────────────────────────────

class _PrescriberPickerField extends ConsumerWidget {
  final Prescriber? selected;
  final TextEditingController searchCtrl;
  final TextEditingController freeTextCtrl;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Prescriber> onSelected;
  final VoidCallback onClear;
  final VoidCallback onAddNew;

  const _PrescriberPickerField({
    required this.selected,
    required this.searchCtrl,
    required this.freeTextCtrl,
    required this.query,
    required this.onQueryChanged,
    required this.onSelected,
    required this.onClear,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If a prescriber is selected, show badge
    if (selected != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medical_information_rounded,
                  color: EnhancedTheme.accentPurple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected!.name,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (selected!.licenseNumber != null ||
                      selected!.specialty != null)
                    Text(
                      [
                        if (selected!.licenseNumber != null)
                          selected!.licenseNumber!,
                        selected!.specialtyLabel,
                      ].join(' · '),
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 11),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  color: Colors.black45, size: 20),
            ),
          ],
        ),
      );
    }

    // Search field + live results
    final prescriberAsync =
        query.length >= 2 ? ref.watch(prescriberListProvider(query)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchCtrl,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: "Search prescriber by name or license…",
            hintStyle:
                const TextStyle(color: Colors.black38, fontSize: 13),
            prefixIcon: const Icon(Icons.medical_information_rounded,
                color: Colors.black45, size: 18),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: Colors.black45, size: 18),
                    onPressed: () {
                      searchCtrl.clear();
                      onQueryChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: EnhancedTheme.accentPurple),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: onQueryChanged,
        ),

        // Autocomplete results
        if (prescriberAsync != null)
          prescriberAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: EnhancedTheme.accentPurple,
                          strokeWidth: 2))),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (prescribers) {
              if (prescribers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No prescribers found for "$query"',
                      style: const TextStyle(
                          color: Colors.black38, fontSize: 12)),
                );
              }
              return Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: prescribers
                      .take(5)
                      .map((p) => InkWell(
                            onTap: () => onSelected(p),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                      Icons.person_rounded,
                                      color: Colors.black45,
                                      size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        Text(
                                          [
                                            if (p.licenseNumber != null)
                                              p.licenseNumber!,
                                            p.specialtyLabel,
                                          ].join(' · '),
                                          style: const TextStyle(
                                              color: Colors.black45,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              );
            },
          ),

        // "or use free text" fallback + "add new" button
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: freeTextCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Or type doctor's name manually",
                  hintStyle: const TextStyle(
                      color: Colors.black38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAddNew,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: EnhancedTheme.accentPurple
                          .withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: EnhancedTheme.accentPurple, size: 16),
                    SizedBox(width: 4),
                    Text('Add',
                        style: TextStyle(
                            color: EnhancedTheme.accentPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
