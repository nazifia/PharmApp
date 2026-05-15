import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';
import '../providers/prescription_provider.dart';
import '../../../shared/models/prescription.dart';

class PrescriptionListScreen extends ConsumerStatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  ConsumerState<PrescriptionListScreen> createState() =>
      _PrescriptionListScreenState();
}

class _PrescriptionListScreenState
    extends ConsumerState<PrescriptionListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _tabIndex = 0; // 0=All, 1=Pending, 2=Partial, 3=Dispensed

  static const _tabs = ['All', 'Pending', 'Partial', 'Dispensed'];
  static const _statusMap = [null, 'pending', 'partial', 'dispensed'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  PrescriptionFilter get _filter => PrescriptionFilter(
        status: _statusMap[_tabIndex],
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return EnhancedTheme.warningAmber;
      case 'partial':
        return EnhancedTheme.accentCyan;
      case 'dispensed':
        return EnhancedTheme.successGreen;
      default:
        return Colors.white54;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'partial':
        return 'Partial';
      case 'dispensed':
        return 'Dispensed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canWrite =
        Rbac.can(user, AppPermission.writePrescriptions);
    final prescriptionsAsync =
        ref.watch(prescriptionListProvider(_filter));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/dashboard/prescriptions/write'),
              backgroundColor: EnhancedTheme.primaryTeal,
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              label: const Text('Write Rx',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                _buildTabs(),
                Expanded(
                  child: prescriptionsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.primaryTeal)),
                    error: (e, _) => _ErrorView(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(prescriptionListProvider(_filter))),
                    data: (list) => list.isEmpty
                        ? _EmptyView(tabIndex: _tabIndex)
                        : _PrescriptionGrid(
                            prescriptions: list,
                            statusColor: _statusColor,
                            statusLabel: _statusLabel,
                            canWrite: canWrite,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.menu_rounded,
                    color: Colors.black87, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prescriptions',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                Text('Medication prescriptions',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.invalidate(prescriptionListProvider(_filter)),
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.black54, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search by patient name or phone…',
          hintStyle:
              TextStyle(color: Colors.black38, fontSize: 14),
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
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: EnhancedTheme.primaryTeal),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = _tabIndex == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? EnhancedTheme.primaryTeal
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? EnhancedTheme.primaryTeal
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black54,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PrescriptionGrid extends StatelessWidget {
  final List<Prescription> prescriptions;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final bool canWrite;

  const _PrescriptionGrid({
    required this.prescriptions,
    required this.statusColor,
    required this.statusLabel,
    required this.canWrite,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: prescriptions.length,
      itemBuilder: (ctx, i) {
        final rx = prescriptions[i];
        return _PrescriptionCard(
          prescription: rx,
          statusColor: statusColor,
          statusLabel: statusLabel,
          canWrite: canWrite,
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: i * 40), duration: 300.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class _PrescriptionCard extends ConsumerStatefulWidget {
  final Prescription prescription;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final bool canWrite;

  const _PrescriptionCard({
    required this.prescription,
    required this.statusColor,
    required this.statusLabel,
    required this.canWrite,
  });

  @override
  ConsumerState<_PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends ConsumerState<_PrescriptionCard> {
  bool _dispensing = false;

  Future<void> _quickDispenseAll() async {
    final rx = widget.prescription;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Dispense',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Dispense all ${rx.undispensedCount} pending medication(s) for ${rx.customerName}?',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Dispense'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _dispensing = true);
    final result = await ref
        .read(prescriptionNotifierProvider.notifier)
        .dispense(rx.id);
    if (!mounted) return;
    setState(() => _dispensing = false);

    if (result != null) {
      ref.invalidate(prescriptionListProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text('Medications dispensed.',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ));
    } else {
      final notifierState = ref.read(prescriptionNotifierProvider);
      Color bg;
      Widget content;
      if (notifierState is AsyncError) {
        bg = EnhancedTheme.errorRed;
        content = Text(
          notifierState.error.toString().replaceFirst('Exception: ', ''),
          style: const TextStyle(color: Colors.white),
        );
      } else {
        bg = EnhancedTheme.warningAmber;
        content = const Row(children: [
          Icon(Icons.wifi_off_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Expanded(
              child: Text('Queued for sync when back online.',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600))),
        ]);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: content,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rx = widget.prescription;
    final sColor = widget.statusColor(rx.status);
    final showDispense =
        widget.canWrite && (rx.isPending || rx.isPartial);

    return GestureDetector(
      onTap: () => context.push('/dashboard/prescriptions/${rx.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: EnhancedTheme.primaryTeal, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rx.customerName,
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                        if (rx.customerPhone.isNotEmpty)
                          Text(rx.customerPhone,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: sColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      widget.statusLabel(rx.status),
                      style: TextStyle(
                          color: sColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.medication_rounded,
                    label: '${rx.medications.length} med'
                        '${rx.medications.length == 1 ? '' : 's'}',
                  ),
                  const SizedBox(width: 8),
                  if (rx.undispensedCount > 0)
                    _InfoChip(
                      icon: Icons.pending_rounded,
                      label: '${rx.undispensedCount} pending',
                      color: EnhancedTheme.warningAmber,
                    ),
                  const SizedBox(width: 8),
                  if (rx.doctorName != null && rx.doctorName!.isNotEmpty)
                    _InfoChip(
                      icon: Icons.person_rounded,
                      label: 'Dr. ${rx.doctorName}',
                    ),
                ],
              ),
              if (rx.pharmacyName != null &&
                  rx.pharmacyName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.local_pharmacy_rounded,
                        size: 13, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(rx.pharmacyName!,
                        style: const TextStyle(
                            color: Colors.black38, fontSize: 11)),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rx.createdAt,
                      style: const TextStyle(
                          color: Colors.black38, fontSize: 11)),
                  if (rx.createdByName != null)
                    Text('by ${rx.createdByName}',
                        style: const TextStyle(
                            color: Colors.black38, fontSize: 11)),
                ],
              ),
              if (showDispense) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rx.undispensedCount} medication(s) pending',
                        style: const TextStyle(
                            color: Colors.black45, fontSize: 11),
                      ),
                    ),
                    GestureDetector(
                      onTap: _dispensing ? null : _quickDispenseAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.successGreen
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: EnhancedTheme.successGreen
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_dispensing)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: EnhancedTheme.successGreen),
                              )
                            else
                              const Icon(Icons.done_all_rounded,
                                  color: EnhancedTheme.successGreen,
                                  size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'Dispense All',
                              style: TextStyle(
                                color: _dispensing
                                    ? EnhancedTheme.successGreen
                                        .withValues(alpha: 0.5)
                                    : EnhancedTheme.successGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = Colors.black45,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final int tabIndex;
  const _EmptyView({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final messages = [
      'No prescriptions yet.',
      'No pending prescriptions.',
      'No partially dispensed prescriptions.',
      'No dispensed prescriptions.',
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 56, color: Colors.black26),
          const SizedBox(height: 16),
          Text(messages[tabIndex],
              style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Tap the button below to write a new prescription.',
              style: TextStyle(
                  color: Colors.black38,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: EnhancedTheme.errorRed.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
