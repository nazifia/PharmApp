import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/hospital.dart';
import 'package:pharmapp/shared/models/prescriber.dart';
import '../providers/hospital_provider.dart';
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
  late final TextEditingController _addressCtrl;
  Hospital? _selectedHospital;
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
    _nameCtrl      = TextEditingController(text: p?.name ?? '');
    _licenseCtrl   = TextEditingController(text: p?.licenseNumber ?? '');
    _specialtyCtrl = TextEditingController(text: p?.specialty ?? '');
    _phoneCtrl     = TextEditingController(text: p?.phone ?? '');
    _addressCtrl   = TextEditingController(text: p?.address ?? '');
    if (p?.hospitalId != null) {
      _selectedHospital = Hospital(
        id:   p!.hospitalId!,
        name: p.hospitalName ?? '',
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _specialtyCtrl.dispose();
    _phoneCtrl.dispose();
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
      if (_selectedHospital != null) 'hospital_id': _selectedHospital!.id,
      if (_addressCtrl.text.trim().isNotEmpty)
        'address': _addressCtrl.text.trim(),
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

  void _pickHospital() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HospitalPickerSheet(
        selected: _selectedHospital,
        onSelected: (h) => setState(() => _selectedHospital = h),
      ),
    );
  }

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
                          color: EnhancedTheme.accentPurple.withValues(alpha: 0.4),
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
                          color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
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
                      initialValue: TextEditingValue(text: _specialtyCtrl.text),
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
                      optionsViewBuilder: (ctx, onSel, options) => Align(
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

                    // Hospital picker
                    _label('Hospital / Clinic'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickHospital,
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
                                color: EnhancedTheme.accentPurple, size: 18),
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
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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

  InputDecoration _inputDec(String label, IconData? icon,
          [BuildContext? ctx]) =>
      InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: (ctx ?? context).subLabelColor, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: EnhancedTheme.accentPurple, size: 18)
            : null,
        filled: true,
        fillColor: (ctx ?? context).cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: (ctx ?? context).borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: (ctx ?? context).borderColor)),
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


// ── Hospital picker bottom sheet ──────────────────────────────────────────────

class HospitalPickerSheet extends ConsumerStatefulWidget {
  final Hospital? selected;
  final ValueChanged<Hospital?> onSelected;

  const HospitalPickerSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  ConsumerState<HospitalPickerSheet> createState() =>
      _HospitalPickerSheetState();
}

class _HospitalPickerSheetState extends ConsumerState<HospitalPickerSheet> {
  final _searchCtrl  = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  String _query      = '';
  bool _showCreate   = false;
  bool _creating     = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHospital() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);

    final h = await ref.read(hospitalNotifierProvider.notifier).createHospital({
      'name': name,
      if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
    });

    if (mounted) setState(() => _creating = false);
    if (h != null && mounted) {
      widget.onSelected(h);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalsAsync = ref.watch(hospitalListProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Select Hospital',
                        style: GoogleFonts.outfit(
                            color: context.labelColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showCreate = !_showCreate),
                      icon: Icon(
                        _showCreate
                            ? Icons.list_rounded
                            : Icons.add_rounded,
                        size: 16,
                        color: EnhancedTheme.primaryTeal,
                      ),
                      label: Text(
                        _showCreate ? 'Browse' : 'New',
                        style: const TextStyle(
                            color: EnhancedTheme.primaryTeal,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_showCreate) ...[
                // ── Create hospital inline ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _pickerField(_nameCtrl, 'Hospital Name *',
                          Icons.local_hospital_rounded, context),
                      const SizedBox(height: 10),
                      _pickerField(_cityCtrl, 'City', Icons.location_city_rounded, context),
                      const SizedBox(height: 10),
                      _pickerField(_phoneCtrl, 'Phone', Icons.phone_rounded, context,
                          keyboard: TextInputType.phone),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _creating ? null : _createHospital,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EnhancedTheme.primaryTeal,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _creating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black))
                              : const Text('Create & Select',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ] else ...[
                // ── Search ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: context.labelColor, fontSize: 14),
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search hospitals…',
                      hintStyle: TextStyle(
                          color: context.hintColor, fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: context.hintColor),
                      filled: true,
                      fillColor: context.cardColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: context.borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: context.borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: EnhancedTheme.primaryTeal)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── List ────────────────────────────────────────────────────
                Expanded(
                  child: hospitalsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.primaryTeal)),
                    error: (e, _) => Center(
                        child: Text('Error: $e',
                            style: TextStyle(color: context.subLabelColor))),
                    data: (hospitals) {
                      if (hospitals.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_hospital_outlined,
                                  size: 48,
                                  color: context.iconOnBg
                                      .withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              Text(
                                _query.isEmpty
                                    ? 'No hospitals yet'
                                    : 'No results for "$_query"',
                                style: TextStyle(
                                    color: context.hintColor, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _showCreate = true),
                                icon: const Icon(Icons.add_rounded,
                                    size: 16,
                                    color: EnhancedTheme.primaryTeal),
                                label: const Text('Add new hospital',
                                    style: TextStyle(
                                        color: EnhancedTheme.primaryTeal,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: hospitals.length,
                        itemBuilder: (_, i) {
                          final h = hospitals[i];
                          final isSelected =
                              widget.selected?.id == h.id;
                          return ListTile(
                            onTap: () {
                              widget.onSelected(h);
                              Navigator.of(context).pop();
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            tileColor: isSelected
                                ? EnhancedTheme.primaryTeal
                                    .withValues(alpha: 0.12)
                                : null,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.primaryTeal
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.local_hospital_rounded,
                                  color: EnhancedTheme.primaryTeal,
                                  size: 18),
                            ),
                            title: Text(h.name,
                                style: TextStyle(
                                    color: context.labelColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: h.city != null
                                ? Text(h.city!,
                                    style: TextStyle(
                                        color: context.subLabelColor,
                                        fontSize: 12))
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: EnhancedTheme.primaryTeal,
                                    size: 18)
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    BuildContext ctx, {
    TextInputType? keyboard,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: TextStyle(color: ctx.labelColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: ctx.subLabelColor, fontSize: 13),
          prefixIcon:
              Icon(icon, color: EnhancedTheme.primaryTeal, size: 18),
          filled: true,
          fillColor: ctx.cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ctx.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ctx.borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: EnhancedTheme.primaryTeal, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}
