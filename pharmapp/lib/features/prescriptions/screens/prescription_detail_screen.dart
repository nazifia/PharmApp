import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import '../providers/prescription_api_client.dart';
import '../providers/prescription_provider.dart';
import '../../../shared/models/prescription.dart';

class PrescriptionDetailScreen extends ConsumerStatefulWidget {
  final int prescriptionId;
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  ConsumerState<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState
    extends ConsumerState<PrescriptionDetailScreen> {
  final Set<int> _selectedIndices = {};
  bool _selectMode = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canWrite = Rbac.can(user, AppPermission.writePrescriptions);
    final rxAsync =
        ref.watch(prescriptionDetailProvider(widget.prescriptionId));
    final notifierState = ref.watch(prescriptionNotifierProvider);
    final isBusy = notifierState is AsyncLoading;

    return Scaffold(
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
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.black87, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Prescription Details',
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (canWrite)
                        rxAsync.whenOrNull(
                          data: (rx) => rx.isPending || rx.isPartial
                              ? TextButton.icon(
                                  onPressed: _selectMode
                                      ? () => setState(() {
                                            _selectMode = false;
                                            _selectedIndices.clear();
                                          })
                                      : () =>
                                          setState(() => _selectMode = true),
                                  icon: Icon(
                                    _selectMode
                                        ? Icons.close_rounded
                                        : Icons.checklist_rounded,
                                    color: EnhancedTheme.accentCyan,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _selectMode ? 'Cancel' : 'Select',
                                    style: const TextStyle(
                                        color: EnhancedTheme.accentCyan),
                                  ),
                                )
                              : null,
                        ) ??
                        const SizedBox(),
                    ],
                  ),
                ),
                // Body content
                Expanded(
                  child: rxAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.primaryTeal)),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(e.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(
                                prescriptionDetailProvider(
                                    widget.prescriptionId)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: EnhancedTheme.primaryTeal,
                                foregroundColor: Colors.white),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (rx) => Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          children: [
                            _PatientCard(rx: rx),
                            const SizedBox(height: 16),
                            if (rx.diagnosis != null &&
                                rx.diagnosis!.isNotEmpty) ...[
                              _InfoSection(
                                label: 'Diagnosis',
                                value: rx.diagnosis!,
                                icon: Icons.local_hospital_rounded,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (rx.notes != null && rx.notes!.isNotEmpty) ...[
                              _InfoSection(
                                label: 'Notes',
                                value: rx.notes!,
                                icon: Icons.notes_rounded,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _MedicationHeader(
                              rx: rx,
                              selectMode: _selectMode,
                              selectedCount: _selectedIndices.length,
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(rx.medications.length, (i) {
                              final med = rx.medications[i];
                              return _MedicationCard(
                                med: med,
                                index: i,
                                selectMode: _selectMode,
                                isSelected: _selectedIndices.contains(i),
                                onToggleSelect: () => setState(() {
                                  if (_selectedIndices.contains(i)) {
                                    _selectedIndices.remove(i);
                                  } else {
                                    _selectedIndices.add(i);
                                  }
                                }),
                                canDispense: canWrite && !med.isDispensed,
                                onDispenseSingle: () =>
                                    _dispense(rx, indices: [i]),
                                onCheckAvailability: () =>
                                    _showAvailability(med),
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(milliseconds: i * 50))
                                  .slideY(begin: 0.05, end: 0);
                            }),
                          ],
                        ),
                        if (canWrite && (rx.isPending || rx.isPartial))
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _BottomActions(
                              rx: rx,
                              selectMode: _selectMode,
                              selectedIndices: _selectedIndices,
                              isBusy: isBusy,
                              onDispenseAll: () => _dispense(rx),
                              onDispenseSelected: () => _dispense(rx,
                                  indices: _selectedIndices.toList()),
                            ),
                          ),
                      ],
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

  void _showAvailability(PrescriptionItem med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvailabilitySheet(med: med),
    );
  }

  Future<void> _dispense(Prescription rx, {List<int>? indices}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Dispense',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          indices == null
              ? 'Dispense all pending medications?'
              : 'Dispense ${indices.length} selected medication(s)?',
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.successGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Dispense'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result = await ref
        .read(prescriptionNotifierProvider.notifier)
        .dispense(rx.id, itemIndices: indices);

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _selectMode = false;
        _selectedIndices.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text('Medications dispensed successfully.',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ));
    } else {
      // queued offline
      final notifierState = ref.read(prescriptionNotifierProvider);
      if (notifierState is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Text(
            notifierState.error.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.warningAmber,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: const Row(children: [
            Icon(Icons.wifi_off_rounded, color: Colors.black, size: 20),
            SizedBox(width: 10),
            Expanded(
                child: Text('Queued for sync when back online.',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }
}

// ── Patient card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Prescription rx;
  const _PatientCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (rx.status) {
      case 'pending':
        statusColor = EnhancedTheme.warningAmber;
        break;
      case 'partial':
        statusColor = EnhancedTheme.accentCyan;
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    color: EnhancedTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rx.customerName,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    if (rx.customerPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 13,
                              color: Colors.black45),
                          const SizedBox(width: 4),
                          Text(rx.customerPhone,
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13)),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  rx.status[0].toUpperCase() + rx.status.substring(1),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (rx.doctorName != null && rx.doctorName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.medical_information_rounded,
                    size: 15,
                    color: Colors.black45),
                const SizedBox(width: 6),
                Text('Dr. ${rx.doctorName}',
                    style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rx.createdAt,
                  style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 11)),
              if (rx.createdByName != null)
                Text('by ${rx.createdByName}',
                    style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11)),
            ],
          ),
          if (rx.pharmacyName != null && rx.pharmacyName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.local_pharmacy_rounded,
                    size: 13,
                    color: Colors.black38),
                const SizedBox(width: 4),
                Text(rx.pharmacyName!,
                    style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Info section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoSection({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: EnhancedTheme.accentCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Medication header ─────────────────────────────────────────────────────────

class _MedicationHeader extends StatelessWidget {
  final Prescription rx;
  final bool selectMode;
  final int selectedCount;

  const _MedicationHeader({
    required this.rx,
    required this.selectMode,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.medication_rounded,
            color: EnhancedTheme.primaryTeal, size: 18),
        const SizedBox(width: 8),
        Text('Medications (${rx.medications.length})',
            style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        const Spacer(),
        if (rx.undispensedCount > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  EnhancedTheme.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.4)),
            ),
            child: Text('${rx.undispensedCount} pending',
                style: const TextStyle(
                    color: EnhancedTheme.warningAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ── Medication card ───────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  final PrescriptionItem med;
  final int index;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final bool canDispense;
  final VoidCallback onDispenseSingle;
  final VoidCallback onCheckAvailability;

  const _MedicationCard({
    required this.med,
    required this.index,
    required this.selectMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.canDispense,
    required this.onDispenseSingle,
    required this.onCheckAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = med.isDispensed
        ? EnhancedTheme.successGreen.withValues(alpha: 0.3)
        : isSelected
            ? EnhancedTheme.primaryTeal.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.08);

    final bgColor = med.isDispensed
        ? EnhancedTheme.successGreen.withValues(alpha: 0.06)
        : isSelected
            ? EnhancedTheme.primaryTeal.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: selectMode && canDispense ? onToggleSelect : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (selectMode && canDispense) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelect(),
                activeColor: EnhancedTheme.primaryTeal,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: med.isDispensed
                      ? EnhancedTheme.successGreen.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  med.isDispensed
                      ? Icons.check_circle_rounded
                      : Icons.medication_liquid_rounded,
                  color: med.isDispensed
                      ? EnhancedTheme.successGreen
                      : Colors.black45,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.itemName,
                      style: TextStyle(
                          color: med.isDispensed
                              ? Colors.black38
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: med.isDispensed
                              ? TextDecoration.lineThrough
                              : null)),
                  if (med.brand != null && med.brand!.isNotEmpty)
                    Text(med.brand!,
                        style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _Tag('${med.quantity} ${med.unit}'),
                      if (med.dosage != null && med.dosage!.isNotEmpty)
                        _Tag(med.dosage!,
                            color: EnhancedTheme.accentCyan),
                      if (med.duration != null && med.duration!.isNotEmpty)
                        _Tag(med.duration!,
                            color: EnhancedTheme.accentPurple),
                    ],
                  ),
                  if (med.instructions != null &&
                      med.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(med.instructions!,
                        style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            if (!selectMode) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onCheckAvailability,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentCyan
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: EnhancedTheme.accentCyan
                                .withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_rounded,
                              color: EnhancedTheme.accentCyan, size: 13),
                          SizedBox(width: 3),
                          Text('Avail.',
                              style: TextStyle(
                                  color: EnhancedTheme.accentCyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  if (canDispense) ...[
                    const SizedBox(height: 5),
                    TextButton(
                      onPressed: onDispenseSingle,
                      style: TextButton.styleFrom(
                        backgroundColor:
                            EnhancedTheme.successGreen.withValues(alpha: 0.12),
                        foregroundColor: EnhancedTheme.successGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Dispense',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ] else if (med.isDispensed) ...[
                    const SizedBox(height: 5),
                    Icon(Icons.done_all_rounded,
                        color: EnhancedTheme.successGreen.withValues(alpha: 0.6),
                        size: 18),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, {this.color = Colors.black45});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Availability bottom sheet ─────────────────────────────────────────────────

class _AvailabilitySheet extends ConsumerWidget {
  final PrescriptionItem med;
  const _AvailabilitySheet({required this.med});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query =
        MedicationAvailabilityQuery(name: med.itemName, brand: med.brand);
    final availAsync = ref.watch(medicationAvailabilityProvider(query));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store_rounded,
                    color: EnhancedTheme.primaryTeal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.itemName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (med.brand != null && med.brand!.isNotEmpty)
                      Text(med.brand!,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Stock availability across pharmacies',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          availAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                  child: CircularProgressIndicator(
                      color: EnhancedTheme.primaryTeal)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white38, size: 32),
                    const SizedBox(height: 8),
                    Text(e.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              color: Colors.white24, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'Not available at any pharmacy\nin the network',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(context).size.height * 0.45),
                    child: SingleChildScrollView(
                      child: Column(
                        children:
                            list.map((a) => _AvailabilityTile(a)).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityTile extends StatelessWidget {
  final MedicationAvailability availability;
  const _AvailabilityTile(this.availability);

  @override
  Widget build(BuildContext context) {
    final inStock = availability.stockQuantity > 0;
    final stockColor =
        inStock ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              inStock
                  ? Icons.local_pharmacy_rounded
                  : Icons.remove_shopping_cart_rounded,
              color: stockColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(availability.pharmacyName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (availability.address != null &&
                    availability.address!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 11, color: Colors.white38),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(availability.address!,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ),
                    ],
                  ),
                if (availability.phone != null &&
                    availability.phone!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 11, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text(availability.phone!,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: stockColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  inStock
                      ? '${availability.stockQuantity} in stock'
                      : 'Out of stock',
                  style: TextStyle(
                      color: stockColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final Prescription rx;
  final bool selectMode;
  final Set<int> selectedIndices;
  final bool isBusy;
  final VoidCallback onDispenseAll;
  final VoidCallback onDispenseSelected;

  const _BottomActions({
    required this.rx,
    required this.selectMode,
    required this.selectedIndices,
    required this.isBusy,
    required this.onDispenseAll,
    required this.onDispenseSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: selectMode
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy || selectedIndices.isEmpty
                        ? null
                        : onDispenseSelected,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EnhancedTheme.successGreen,
                      side: const BorderSide(color: EnhancedTheme.successGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EnhancedTheme.successGreen))
                        : Text(
                            selectedIndices.isEmpty
                                ? 'Select medications'
                                : 'Dispense ${selectedIndices.length} selected',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            )
          : ElevatedButton.icon(
              onPressed: isBusy ? null : onDispenseAll,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.done_all_rounded, size: 20),
              label: Text(
                rx.isPartial
                    ? 'Dispense Remaining (${rx.undispensedCount})'
                    : 'Dispense All (${rx.medications.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.successGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }
}
