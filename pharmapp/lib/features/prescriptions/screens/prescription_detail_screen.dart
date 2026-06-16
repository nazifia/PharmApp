import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/features/pos/providers/cart_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
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
  Prescription? _localRx; // optimistic update applied immediately on dispense

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canWrite = Rbac.can(user, AppPermission.writePrescriptions);
    final rxAsync =
        ref.watch(prescriptionDetailProvider(widget.prescriptionId));
    final notifierState = ref.watch(prescriptionNotifierProvider);
    final isBusy = notifierState is AsyncLoading;

    // Clear the optimistic copy once the server re-fetch delivers fresh data
    ref.listen(prescriptionDetailProvider(widget.prescriptionId),
        (_, next) {
      if (next is AsyncData && _localRx != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) {
          if (mounted) setState(() => _localRx = null);
        });
      }
    });

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
                          data: (serverRx) {
                            final rx = _localRx ?? serverRx;
                            return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _showEditSheet(rx),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.12)),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.black54, size: 18),
                                ),
                              ),
                              if (rx.isPending || rx.isPartial) ...[
                                const SizedBox(width: 6),
                                TextButton.icon(
                                  onPressed: _selectMode
                                      ? () => setState(() {
                                            _selectMode = false;
                                            _selectedIndices.clear();
                                          })
                                      : () => setState(
                                          () => _selectMode = true),
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
                                ),
                              ],
                            ],
                          );},
                        ) ??
                        const SizedBox(),
                    ],
                  ),
                ),
                // Body content
                Expanded(
                  child: rxAsync.when(
                    skipLoadingOnReload: true,
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
                    data: (serverRx) {
                      final rx = _localRx ?? serverRx;
                      final isCrossOrg = rx.isPortalRx ||
                          (rx.pharmacyId != null &&
                          rx.pharmacyId != user?.organizationId);
                      return Stack(
                      children: [
                        ListView(
                          padding: EdgeInsets.fromLTRB(16, 8, 16,
                              canWrite && _selectMode && (rx.isPending || rx.isPartial) ? 120.0 : 24.0),
                          children: [
                            _PatientCard(rx: rx, isCrossOrg: isCrossOrg),
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
                            if (rx.consultationFee > 0 ||
                                (rx.consultationCategory != null &&
                                    rx.consultationCategory!.isNotEmpty)) ...[
                              _InfoSection(
                                label: rx.consultationCategory != null &&
                                        rx.consultationCategory!.isNotEmpty
                                    ? 'Consultation Fee · Category ${rx.consultationCategory}'
                                    : 'Consultation Fee',
                                value:
                                    '${fmtN(rx.consultationFee)}  (added at payment, not shown on receipt)',
                                icon: Icons.medical_information_rounded,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (rx.refillsAllowed > 0) ...[
                              _RefillSection(
                                rx: rx,
                                canWrite: canWrite,
                                isBusy: isBusy,
                                onRefill: () => _requestRefill(rx),
                              ),
                              const SizedBox(height: 16),
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
                                onAddToCart: med.isDispensed
                                    ? null
                                    : () => _addToCart(med, i, rx.id,
                                        consultationFee: rx.consultationFee),
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(milliseconds: i * 50))
                                  .slideY(begin: 0.05, end: 0);
                            }),
                          ],
                        ),
                        if (canWrite && _selectMode && (rx.isPending || rx.isPartial))
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _BottomActions(
                              selectedIndices: _selectedIndices,
                              isBusy: isBusy,
                              onDispenseSelected: () => _dispense(rx,
                                  indices: _selectedIndices.toList()),
                            ),
                          ),
                      ],
                    );},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(PrescriptionItem med, int medIndex, int prescriptionId,
      {double consultationFee = 0}) async {
    Item? item;

    if (med.itemId != null) {
      try {
        item = await ref.read(inventoryApiProvider).fetchById(med.itemId!);
      } catch (_) {}
    }

    if (item == null && mounted) {
      item = await showModalBottomSheet<Item>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ItemPickerSheet(initialSearch: med.itemName),
      );
    }

    if (item == null || !mounted) return;

    if (item.stock == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text('${item.name} is out of stock.',
            style: const TextStyle(color: Colors.white)),
      ));
      return;
    }

    _commitToCart(item, med.quantity.round().clamp(1, item.stock));

    // Register binding so the POS checkout automatically dispenses this medication slot.
    ref.read(prescriptionCartBindingsProvider.notifier).update((b) {
      final updated = Map<int, List<int>>.from(b);
      final indices = List<int>.from(updated[prescriptionId] ?? []);
      if (!indices.contains(medIndex)) indices.add(medIndex);
      updated[prescriptionId] = indices;
      return updated;
    });

    // Attach the consultation surcharge once per prescription — charged silently
    // at POS checkout, never itemised on the customer receipt.
    if (consultationFee > 0) {
      ref.read(prescriptionConsultationFeesProvider.notifier).update((m) {
        final updated = Map<int, double>.from(m);
        updated[prescriptionId] = consultationFee;
        return updated;
      });
    }

    if (!mounted) return;
    final resolvedItem = item;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${resolvedItem.name} added to cart',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      action: SnackBarAction(
        label: 'Go to POS',
        textColor: Colors.white,
        onPressed: () => context.go('/dashboard/pos'),
      ),
    ));
  }

  void _commitToCart(Item item, int quantity) {
    final cart = ref.read(cartProvider.notifier);
    final existing =
        ref.read(cartProvider).where((c) => c.item.id == item.id).firstOrNull;
    if (existing == null) {
      cart.addItem(item);
      if (quantity > 1) cart.updateQuantity(item.id, quantity);
    } else {
      cart.updateQuantity(
          item.id, (existing.quantity + quantity).clamp(1, item.stock));
    }
  }

  void _showEditSheet(Prescription rx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPrescriptionSheet(
        rx: rx,
        onSave: (data) async {
          Navigator.pop(context);
          final result = await ref
              .read(prescriptionNotifierProvider.notifier)
              .update(rx.id, data);
          if (!mounted) return;
          final notifierState = ref.read(prescriptionNotifierProvider);
          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: EnhancedTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              content: const Row(children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Prescription updated.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ));
          } else if (notifierState is AsyncError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: EnhancedTheme.errorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              content: Text(
                  notifierState.error.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: Colors.white)),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: EnhancedTheme.warningAmber,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              content: const Row(children: [
                Icon(Icons.wifi_off_rounded, color: Colors.black, size: 20),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Queued for sync when back online.',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600))),
              ]),
            ));
          }
        },
      ),
    );
  }

  void _showAvailability(PrescriptionItem med) {
    // Navigate to the full-screen network availability view.
    // Falls back to the inline bottom sheet if the route is not reachable.
    final encoded = Uri.encodeComponent(med.itemName);
    context.go('/dashboard/medication-availability/$encoded');
  }

  Future<void> _requestRefill(Prescription rx) async {
    if (!rx.canRefill) return;
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Request Refill',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Request refill ${rx.refillsUsed + 1} of ${rx.refillsAllowed} for ${rx.customerName}?',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result = await ref
        .read(prescriptionNotifierProvider.notifier)
        .requestRefill(rx.id);

    if (!mounted) return;
    if (result != null) {
      setState(() => _localRx = result);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text('Refill requested successfully.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ));
    } else {
      final notifierState = ref.read(prescriptionNotifierProvider);
      if (notifierState is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Text(
              notifierState.error.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.white)),
        ));
      }
    }
  }

  Prescription _recomputeStatus(Prescription rx) {
    final allDone = rx.medications.every((m) => m.isDispensed);
    final anyDone = rx.medications.any((m) => m.isDispensed);
    final computed = allDone ? 'dispensed' : (anyDone ? 'partial' : 'pending');
    return computed != rx.status ? rx.copyWith(status: computed) : rx;
  }

  Future<void> _dispense(Prescription rx, {List<int>? indices}) async {
    final isCrossOrg = rx.isPortalRx ||
        (rx.pharmacyId != null &&
        rx.pharmacyId != ref.read(currentUserProvider)?.organizationId);
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Dispense',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              indices == null
                  ? 'Dispense all pending medications?'
                  : 'Dispense ${indices.length} selected medication(s)?',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            if (isCrossOrg) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: rx.isPortalRx
                      ? EnhancedTheme.accentPurple.withValues(alpha: 0.12)
                      : EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: rx.isPortalRx
                          ? EnhancedTheme.accentPurple.withValues(alpha: 0.3)
                          : EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      rx.isPortalRx
                          ? Icons.send_to_mobile_rounded
                          : Icons.swap_horiz_rounded,
                      color: rx.isPortalRx
                          ? EnhancedTheme.accentPurple
                          : EnhancedTheme.accentCyan,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rx.isPortalRx
                            ? 'Portal prescription — dispensing at your pharmacy.'
                            : 'Written by ${rx.pharmacyName ?? 'network pharmacy'}. Dispensing at your pharmacy.',
                        style: TextStyle(
                            color: rx.isPortalRx
                                ? EnhancedTheme.accentPurple
                                : EnhancedTheme.accentCyan,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

    // Determine which medication indices to dispense.
    // When indices is null, dispense every medication that is still pending.
    final now = DateTime.now().toIso8601String();
    final targetIndices = indices ??
        List.generate(rx.medications.length, (i) => i)
            .where((i) => !rx.medications[i].isDispensed)
            .toList();

    // Build the optimistic prescription immediately so the UI responds at once.
    final optimisticMeds = rx.medications.asMap().entries.map((e) {
      if (targetIndices.contains(e.key) && !e.value.isDispensed) {
        return e.value.copyWith(isDispensed: true, dispensedAt: now);
      }
      return e.value;
    }).toList();

    final allDone = optimisticMeds.every((m) => m.isDispensed);
    final anyDone = optimisticMeds.any((m) => m.isDispensed);
    final optimisticStatus =
        allDone ? 'dispensed' : (anyDone ? 'partial' : rx.status);

    final optimisticRx = rx.copyWith(
      medications: optimisticMeds,
      status: optimisticStatus,
      dispensedAt: allDone ? now : rx.dispensedAt,
    );

    setState(() {
      _localRx = optimisticRx;
      _selectMode = false;
      _selectedIndices.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text(
          '${targetIndices.length} medication(s) dispensed.',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ]),
    ));

    // Sync with backend.  Pass null when dispensing all so the server handles
    // all-pending logic; pass specific indices for partial dispense.
    final result = await ref
        .read(prescriptionNotifierProvider.notifier)
        .dispense(rx.id, itemIndices: indices);

    if (!mounted) return;

    if (result != null) {
      // Recompute status from medication flags in case backend didn't update it.
      setState(() => _localRx = _recomputeStatus(result));
    } else {
      final notifierState = ref.read(prescriptionNotifierProvider);
      if (notifierState is AsyncError) {
        // Server returned an error — revert the optimistic update.
        setState(() => _localRx = null);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Text(
            notifierState.error.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(color: Colors.white),
          ),
        ));
      } else {
        // Offline — optimistic update stays; queued for sync.
        ScaffoldMessenger.of(context).clearSnackBars();
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
                child: Text('Dispensed locally — will sync when back online.',
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
  final bool isCrossOrg;
  const _PatientCard({required this.rx, this.isCrossOrg = false});

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
          if (isCrossOrg) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: rx.isPortalRx
                    ? EnhancedTheme.accentPurple.withValues(alpha: 0.12)
                    : EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: rx.isPortalRx
                        ? EnhancedTheme.accentPurple.withValues(alpha: 0.3)
                        : EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    rx.isPortalRx
                        ? Icons.send_to_mobile_rounded
                        : Icons.swap_horiz_rounded,
                    color: rx.isPortalRx
                        ? EnhancedTheme.accentPurple
                        : EnhancedTheme.accentCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rx.isPortalRx
                          ? 'Submitted via Prescriber Portal'
                          : 'Written by ${rx.pharmacyName ?? 'network pharmacy'}',
                      style: TextStyle(
                          color: rx.isPortalRx
                              ? EnhancedTheme.accentPurple
                              : EnhancedTheme.accentCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
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
            if (rx.prescriberLicenseNo != null &&
                rx.prescriberLicenseNo!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.badge_rounded,
                      size: 14, color: Colors.black38),
                  const SizedBox(width: 6),
                  Text('Lic: ${rx.prescriberLicenseNo}',
                      style: const TextStyle(
                          color: Colors.black38, fontSize: 12)),
                ],
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        if (!selectMode) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.store_rounded,
                  size: 12, color: Colors.black38),
              SizedBox(width: 4),
              Text(
                'Tap "Where Available" on any item to check pharmacy stock',
                style: TextStyle(color: Colors.black38, fontSize: 11),
              ),
            ],
          ),
        ],
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
  final VoidCallback? onAddToCart;

  const _MedicationCard({
    required this.med,
    required this.index,
    required this.selectMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.canDispense,
    required this.onDispenseSingle,
    required this.onCheckAvailability,
    this.onAddToCart,
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
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentCyan
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: EnhancedTheme.accentCyan
                                .withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_rounded,
                              color: EnhancedTheme.accentCyan, size: 14),
                          SizedBox(width: 4),
                          Text('Where Available',
                              style: TextStyle(
                                  color: EnhancedTheme.accentCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  if (onAddToCart != null) ...[
                    const SizedBox(height: 5),
                    TextButton(
                      onPressed: onAddToCart,
                      style: TextButton.styleFrom(
                        backgroundColor:
                            EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                        foregroundColor: EnhancedTheme.warningAmber,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_rounded, size: 12),
                          SizedBox(width: 4),
                          Text('Add to Cart',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
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

// ── Edit prescription bottom sheet ───────────────────────────────────────────

class _EditPrescriptionSheet extends StatefulWidget {
  final Prescription rx;
  final void Function(Map<String, dynamic>) onSave;
  const _EditPrescriptionSheet({required this.rx, required this.onSave});

  @override
  State<_EditPrescriptionSheet> createState() => _EditPrescriptionSheetState();
}

class _EditPrescriptionSheetState extends State<_EditPrescriptionSheet> {
  late final TextEditingController _doctorCtrl;
  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _consultFeeCtrl;
  late String _status;

  @override
  void initState() {
    super.initState();
    _doctorCtrl = TextEditingController(text: widget.rx.doctorName ?? '');
    _diagnosisCtrl = TextEditingController(text: widget.rx.diagnosis ?? '');
    _notesCtrl = TextEditingController(text: widget.rx.notes ?? '');
    _consultFeeCtrl = TextEditingController(
        text: widget.rx.consultationFee > 0
            ? widget.rx.consultationFee.toStringAsFixed(0)
            : '');
    _status = widget.rx.status;
  }

  @override
  void dispose() {
    _doctorCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    _consultFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: SingleChildScrollView(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Edit Prescription',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              const Text('Status',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _StatusSelector(
                current: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 16),
              _SheetField(
                controller: _doctorCtrl,
                label: 'Doctor Name',
                hint: 'e.g. Dr. Smith',
                icon: Icons.medical_information_rounded,
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: _diagnosisCtrl,
                label: 'Diagnosis',
                hint: 'e.g. Hypertension',
                icon: Icons.local_hospital_rounded,
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: _notesCtrl,
                label: 'Notes',
                hint: 'Additional instructions…',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: _consultFeeCtrl,
                label: 'Consultation Fee (₦) — override',
                hint: 'Charged silently at payment, hidden on receipt',
                icon: Icons.medical_information_rounded,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  widget.onSave({
                    'status': _status,
                    'doctor_name': _doctorCtrl.text.trim(),
                    'diagnosis': _diagnosisCtrl.text.trim(),
                    'notes': _notesCtrl.text.trim(),
                    'consultation_fee':
                        double.tryParse(_consultFeeCtrl.text.trim()) ?? 0,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;
  const _StatusSelector({required this.current, required this.onChanged});

  static const _statuses = ['pending', 'partial', 'dispensed'];
  static const _labels = ['Pending', 'Partial', 'Dispensed'];
  static const _colors = [
    EnhancedTheme.warningAmber,
    EnhancedTheme.accentCyan,
    EnhancedTheme.successGreen,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_statuses.length, (i) {
        final selected = current == _statuses[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(_statuses[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? _colors[i].withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? _colors[i]
                        : Colors.white.withValues(alpha: 0.15),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _colors[i] : Colors.white38,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Colors.white30, fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.white38, size: 18),
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
              borderSide:
                  const BorderSide(color: EnhancedTheme.primaryTeal),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ── Item picker sheet (inventory search) ─────────────────────────────────────

class _ItemPickerSheet extends ConsumerStatefulWidget {
  final String initialSearch;
  const _ItemPickerSheet({required this.initialSearch});

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  late final TextEditingController _ctrl;
  List<Item>? _results;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialSearch);
    _search(widget.initialSearch);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _loading = false; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ref
          .read(inventoryApiProvider)
          .fetchInventory(search: query.trim());
      if (mounted) setState(() { _results = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Find Inventory Item',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Search and select the matching inventory item to add to cart.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search by name or brand…',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.white38, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: EnhancedTheme.primaryTeal)),
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
                borderSide:
                    const BorderSide(color: EnhancedTheme.primaryTeal),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Colors.white24, size: 36),
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }
    final results = _results;
    if (results == null || results.isEmpty) {
      if (_loading) return const SizedBox();
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white24, size: 40),
            SizedBox(height: 12),
            Text('No matching items found in inventory.',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) {
        final item = results[i];
        final inStock = item.stock > 0;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: inStock
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              inStock
                  ? Icons.medication_rounded
                  : Icons.remove_shopping_cart_rounded,
              color: inStock
                  ? EnhancedTheme.primaryTeal
                  : Colors.white24,
              size: 20,
            ),
          ),
          title: Text(item.name,
              style: TextStyle(
                  color: inStock ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          subtitle: Text(
            '${item.brand.isNotEmpty ? item.brand : item.dosageForm}'
            '${item.brand.isNotEmpty && item.dosageForm.isNotEmpty ? ' · ${item.dosageForm}' : ''}',
            style:
                const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                inStock ? '${item.stock} in stock' : 'Out of stock',
                style: TextStyle(
                    color:
                        inStock ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                fmtN(item.price),
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          onTap: inStock ? () => Navigator.pop(context, item) : null,
        );
      },
    );
  }
}

// ── Refill section ────────────────────────────────────────────────────────────

class _RefillSection extends StatelessWidget {
  final Prescription rx;
  final bool canWrite;
  final bool isBusy;
  final VoidCallback onRefill;

  const _RefillSection({
    required this.rx,
    required this.canWrite,
    required this.isBusy,
    required this.onRefill,
  });

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final progress = rx.refillsAllowed > 0
        ? rx.refillsUsed / rx.refillsAllowed
        : 0.0;
    final remaining = rx.refillsAllowed - rx.refillsUsed;
    final progressColor = remaining == 0
        ? EnhancedTheme.errorRed
        : remaining == 1
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.primaryTeal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.repeat_rounded,
                    color: EnhancedTheme.accentPurple, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Refills',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${rx.refillsUsed} of ${rx.refillsAllowed} used',
                      style: TextStyle(
                          color: progressColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (canWrite && rx.canRefill && !isBusy)
                GestureDetector(
                  onTap: onRefill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              EnhancedTheme.primaryTeal.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: EnhancedTheme.primaryTeal, size: 15),
                        SizedBox(width: 5),
                        Text('Request Refill',
                            style: TextStyle(
                                color: EnhancedTheme.primaryTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )
              else if (!rx.canRefill && !rx.isDispensed && rx.refillsAllowed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: EnhancedTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: const Text('No refills left',
                      style: TextStyle(
                          color: EnhancedTheme.errorRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: progressColor,
              minHeight: 6,
            ),
          ),
          if (rx.nextRefillDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: rx.isRefillDueSoon
                      ? EnhancedTheme.warningAmber
                      : Colors.black38,
                ),
                const SizedBox(width: 5),
                Text(
                  'Next refill: ${_formatDate(rx.nextRefillDate!)}',
                  style: TextStyle(
                      color: rx.isRefillDueSoon
                          ? EnhancedTheme.warningAmber
                          : Colors.black38,
                      fontSize: 12,
                      fontWeight: rx.isRefillDueSoon
                          ? FontWeight.w600
                          : FontWeight.normal),
                ),
                if (rx.isRefillDueSoon) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: EnhancedTheme.warningAmber
                              .withValues(alpha: 0.4)),
                    ),
                    child: const Text('Due soon',
                        style: TextStyle(
                            color: EnhancedTheme.warningAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
          if (rx.lastRefillDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 12, color: Colors.black38),
                const SizedBox(width: 5),
                Text(
                  'Last refill: ${_formatDate(rx.lastRefillDate!)}',
                  style: const TextStyle(color: Colors.black38, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final Set<int> selectedIndices;
  final bool isBusy;
  final VoidCallback onDispenseSelected;

  const _BottomActions({
    required this.selectedIndices,
    required this.isBusy,
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
      child: Row(
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
      ),
    );
  }
}
