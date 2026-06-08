import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';
import 'package:pharmapp/shared/widgets/barcode_scanner_sheet.dart';
import 'package:pharmapp/shared/widgets/hardware_scanner_listener.dart';
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
  String _rawSearch = '';
  String _debouncedSearch = '';
  Timer? _debounce;
  int _tabIndex = 1; // 0=All 1=Pending 2=Partial 3=Dispensed
  bool _networkWide = false; // default to own-org view

  static const _tabs = ['All', 'Pending', 'Partial', 'Dispensed'];
  static const _statusMap = [null, 'pending', 'partial', 'dispensed'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _rawSearch = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _debouncedSearch = v);
    });
  }

  void _onBarcodeScannedPrescription(String code) {
    final trimmed = code.trim();
    final id = int.tryParse(trimmed);
    if (id != null) {
      context.push('/dashboard/prescriptions/$id');
      return;
    }
    // Non-numeric code — use as search term.
    _searchCtrl.text = trimmed;
    _onSearchChanged(trimmed);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.infoBlue.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('Searching for "$trimmed"…',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _rawSearch = '';
      _debouncedSearch = '';
    });
  }

  PrescriptionFilter get _filter => PrescriptionFilter(
        status: _statusMap[_tabIndex],
        search: _debouncedSearch.isNotEmpty ? _debouncedSearch : null,
        networkWide: _networkWide,
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
    final canWrite = Rbac.can(user, AppPermission.writePrescriptions);
    final prescriptionsAsync = ref.watch(prescriptionListProvider(_filter));
    final pendingCountAsync = ref.watch(networkPendingCountProvider);

    return HardwareScannerListener(
      onBarcodeScanned: _onBarcodeScannedPrescription,
      child: Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/dashboard/prescriptions/write'),
              backgroundColor: EnhancedTheme.primaryTeal,
              icon:
                  const Icon(Icons.edit_note_rounded, color: Colors.white),
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
                _buildHeader(context, pendingCountAsync),
                _buildScopeToggle(),
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
                        ? _EmptyView(
                            tabIndex: _tabIndex,
                            networkWide: _networkWide,
                            hasSearch: _debouncedSearch.isNotEmpty,
                          )
                        : _PrescriptionList(
                            prescriptions: list,
                            statusColor: _statusColor,
                            statusLabel: _statusLabel,
                            networkWide: _networkWide,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader(
      BuildContext context, AsyncValue<int> pendingCountAsync) {
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
                pendingCountAsync.when(
                  data: (count) => Text(
                    count > 0
                        ? '$count pending across network'
                        : 'No pending prescriptions in network',
                    style: TextStyle(
                      color: count > 0
                          ? EnhancedTheme.warningAmber
                          : Colors.black38,
                      fontSize: 12,
                      fontWeight: count > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  loading: () => const Text('Checking network…',
                      style:
                          TextStyle(color: Colors.black38, fontSize: 12)),
                  error: (_, __) => const Text('Medication prescriptions',
                      style:
                          TextStyle(color: Colors.black38, fontSize: 12)),
                ),
              ],
            ),
          ),
          pendingCountAsync.maybeWhen(
            data: (count) => count > 0
                ? Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: EnhancedTheme.warningAmber
                              .withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: EnhancedTheme.warningAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            onPressed: () {
              ref.invalidate(prescriptionListProvider(_filter));
              ref.invalidate(networkPendingCountProvider);
            },
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.black54, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            _ScopeTab(
              label: 'This Branch',
              icon: Icons.store_rounded,
              selected: !_networkWide,
              onTap: () => setState(() => _networkWide = false),
            ),
            _ScopeTab(
              label: 'All Network',
              icon: Icons.hub_rounded,
              selected: _networkWide,
              onTap: () => setState(() => _networkWide = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: _networkWide
                  ? 'Search name, phone, doctor, diagnosis…'
                  : 'Search by patient name or phone…',
              hintStyle:
                  const TextStyle(color: Colors.black38, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.black45),
              suffixIcon: _rawSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Colors.black45, size: 20),
                      onPressed: _clearSearch,
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showBarcodeScannerSheet(context, _onBarcodeScannedPrescription),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: EnhancedTheme.primaryTeal, size: 22),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

// ── Scope toggle tab ──────────────────────────────────────────────────────────

class _ScopeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? EnhancedTheme.primaryTeal
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? Colors.white : Colors.black45),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black54,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Prescription list ─────────────────────────────────────────────────────────

class _PrescriptionList extends StatelessWidget {
  final List<Prescription> prescriptions;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final bool networkWide;

  const _PrescriptionList({
    required this.prescriptions,
    required this.statusColor,
    required this.statusLabel,
    required this.networkWide,
  });

  @override
  Widget build(BuildContext context) {
    if (!networkWide) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: prescriptions.length,
        itemBuilder: (ctx, i) => _PrescriptionCard(
          prescription: prescriptions[i],
          statusColor: statusColor,
          statusLabel: statusLabel,
          showPharmacy: false,
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: i * 40), duration: 300.ms)
            .slideY(begin: 0.08, end: 0),
      );
    }

    // Network mode: group by branch (server already sends ordered by branch then -created_at).
    // Fall back to pharmacy name for orgs without branch configuration.
    String groupKey(Prescription rx) {
      if (rx.branchName != null && rx.branchName!.isNotEmpty) {
        return rx.branchName!;
      }
      return rx.pharmacyName ?? 'Main Branch';
    }

    final items = <_ListItem>[];
    String? currentGroup;
    for (final rx in prescriptions) {
      final group = groupKey(rx);
      if (group != currentGroup) {
        currentGroup = group;
        items.add(_HeaderItem(group));
      }
      items.add(_CardItem(rx));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item is _HeaderItem) {
          return _PharmacyHeader(name: item.name)
              .animate()
              .fadeIn(
                  delay: Duration(milliseconds: i * 30), duration: 250.ms);
        }
        final rx = (item as _CardItem).prescription;
        return _PrescriptionCard(
          prescription: rx,
          statusColor: statusColor,
          statusLabel: statusLabel,
          showPharmacy: false, // already shown in header
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: i * 30), duration: 280.ms)
            .slideY(begin: 0.06, end: 0);
      },
    );
  }
}

// Simple sealed-class-like approach for list items
abstract class _ListItem {}

class _HeaderItem extends _ListItem {
  final String name;
  _HeaderItem(this.name);
}

class _CardItem extends _ListItem {
  final Prescription prescription;
  _CardItem(this.prescription);
}

// ── Pharmacy section header ───────────────────────────────────────────────────

class _PharmacyHeader extends StatelessWidget {
  final String name;
  const _PharmacyHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_pharmacy_rounded,
                size: 14, color: EnhancedTheme.accentCyan),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: EnhancedTheme.accentCyan,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            width: 60,
            height: 1,
            color: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

// ── Prescription card ─────────────────────────────────────────────────────────

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final bool showPharmacy;

  const _PrescriptionCard({
    required this.prescription,
    required this.statusColor,
    required this.statusLabel,
    required this.showPharmacy,
  });

  @override
  Widget build(BuildContext context) {
    final rx = prescription;
    final sColor = statusColor(rx.status);

    return GestureDetector(
      onTap: () => context.push('/dashboard/prescriptions/${rx.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal
                          .withValues(alpha: 0.15),
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
                                  color: Colors.black54,
                                  fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel(rx.status),
                      style: TextStyle(
                          color: sColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    icon: Icons.medication_rounded,
                    label: '${rx.medications.length} med'
                        '${rx.medications.length == 1 ? '' : 's'}',
                  ),
                  if (rx.undispensedCount > 0)
                    _InfoChip(
                      icon: Icons.pending_rounded,
                      label: '${rx.undispensedCount} pending',
                      color: EnhancedTheme.warningAmber,
                    ),
                  if (rx.isRefillDueSoon)
                    const _InfoChip(
                      icon: Icons.repeat_rounded,
                      label: 'Refill due',
                      color: EnhancedTheme.warningAmber,
                    ),
                  if (rx.refillsAllowed > 0 && !rx.isRefillDueSoon)
                    _InfoChip(
                      icon: Icons.repeat_rounded,
                      label: '${rx.refillsAllowed - rx.refillsUsed} refill'
                          '${rx.refillsAllowed - rx.refillsUsed == 1 ? '' : 's'} left',
                      color: rx.refillsUsed >= rx.refillsAllowed
                          ? EnhancedTheme.errorRed
                          : Colors.black45,
                    ),
                  if (rx.isPortalRx)
                    const _InfoChip(
                      icon: Icons.send_to_mobile_rounded,
                      label: 'Portal Rx',
                      color: EnhancedTheme.accentPurple,
                    ),
                  if (rx.doctorName != null &&
                      rx.doctorName!.isNotEmpty)
                    _InfoChip(
                      icon: Icons.person_rounded,
                      label: 'Dr. ${rx.doctorName}',
                    ),
                  if (rx.diagnosis != null &&
                      rx.diagnosis!.isNotEmpty)
                    _InfoChip(
                      icon: Icons.local_hospital_rounded,
                      label: rx.diagnosis!,
                    ),
                ],
              ),
              if (showPharmacy &&
                  rx.pharmacyName != null &&
                  rx.pharmacyName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.local_pharmacy_rounded,
                        size: 13, color: EnhancedTheme.accentCyan),
                    const SizedBox(width: 4),
                    Text(rx.pharmacyName!,
                        style: const TextStyle(
                            color: EnhancedTheme.accentCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final int tabIndex;
  final bool networkWide;
  final bool hasSearch;

  const _EmptyView({
    required this.tabIndex,
    required this.networkWide,
    required this.hasSearch,
  });

  @override
  Widget build(BuildContext context) {
    final scope = networkWide ? 'across the network' : 'in this branch';

    if (hasSearch) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 52, color: Colors.black26),
            const SizedBox(height: 16),
            const Text('No matches found',
                style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Try a different name, phone, or doctor $scope.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black38, fontSize: 13)),
          ],
        ),
      );
    }

    final messages = [
      'No prescriptions $scope.',
      'No pending prescriptions $scope.',
      'No partially dispensed prescriptions $scope.',
      'No dispensed prescriptions $scope.',
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 56, color: Colors.black26),
          const SizedBox(height: 16),
          Text(messages[tabIndex],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black45, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Tap the button below to write a new prescription.',
              style: TextStyle(color: Colors.black38, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

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
                size: 48,
                color: EnhancedTheme.errorRed.withValues(alpha: 0.7)),
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
