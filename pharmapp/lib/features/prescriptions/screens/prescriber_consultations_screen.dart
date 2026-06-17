import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../../../shared/models/prescriber.dart';
import '../../../shared/models/consultation_payout.dart';
import '../providers/prescriber_provider.dart';

final _fmt = NumberFormat('#,##0.00');

/// Total consultation fees collected per prescriber + payout settlement.
/// Admin view: settle pending payouts (single / Pay All) and notify the
/// prescriber + org-admin of the running total. Prescriber view: read-only
/// earnings ledger.
class PrescriberConsultationsScreen extends ConsumerWidget {
  final Prescriber? prescriber;
  final bool isAdminView;

  const PrescriberConsultationsScreen({
    super.key,
    this.prescriber,
    this.isAdminView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = prescriber ?? ref.watch(currentPrescriberProvider);
    if (p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final summaryAsync = ref.watch(prescriberConsultationSummaryProvider(p.id));
    final listAsync = ref.watch(prescriberConsultationsProvider(p.id));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.10),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── App bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: context.iconOnBg, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.medical_services_rounded,
                            color: EnhancedTheme.accentCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdminView
                                  ? 'Consultation Payouts'
                                  : 'Consultation Fees',
                              style: TextStyle(
                                  color: context.labelColor,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Dr. ${p.name}',
                              style: TextStyle(
                                  color: context.subLabelColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isAdminView)
                        summaryAsync.maybeWhen(
                          data: (s) => GestureDetector(
                            onTap: () => _notify(context, ref, p),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.infoBlue
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: EnhancedTheme.infoBlue
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: EnhancedTheme.infoBlue,
                                  size: 18),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      if (isAdminView) ...[
                        const SizedBox(width: 8),
                        summaryAsync.maybeWhen(
                          data: (s) => s.pendingCount > 0
                              ? GestureDetector(
                                  onTap: () => _payAll(context, ref, s, p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          EnhancedTheme.successGreen,
                                          EnhancedTheme.primaryTeal,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Pay All',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Summary cards ─────────────────────────────────────────
                summaryAsync.when(
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.accentCyan)),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                            child: _SummaryCard(
                          label: 'Total Collected',
                          value: 'NGN ${_fmt.format(s.totalCollected)}',
                          color: EnhancedTheme.primaryTeal,
                          icon: Icons.account_balance_wallet_rounded,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _SummaryCard(
                          label: 'Pending',
                          value: 'NGN ${_fmt.format(s.pendingAmount)}',
                          sublabel: '${s.pendingCount} records',
                          color: EnhancedTheme.warningAmber,
                          icon: Icons.hourglass_top_rounded,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _SummaryCard(
                          label: 'Paid Out',
                          value: 'NGN ${_fmt.format(s.paidAmount)}',
                          sublabel: '${s.paidCount} records',
                          color: EnhancedTheme.successGreen,
                          icon: Icons.check_circle_rounded,
                        )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Payout list ───────────────────────────────────────────
                Expanded(
                  child: listAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.accentCyan)),
                    error: (e, _) => Center(
                      child: Text('Error loading consultations: $e',
                          style: TextStyle(
                              color: context.subLabelColor, fontSize: 13)),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medical_services_outlined,
                                  size: 64,
                                  color:
                                      context.iconOnBg.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No consultation fees yet',
                                style: TextStyle(
                                    color: context.hintColor, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Records are created when a prescription with\na consultation fee is dispensed at the POS.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: context.subLabelColor, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _PayoutTile(
                          payout: list[i],
                          onMarkPaid: isAdminView && !list[i].isPaid
                              ? () => _markPaid(context, ref, list[i], p)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, bool ok, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok
            ? EnhancedTheme.successGreen.withValues(alpha: 0.92)
            : EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _notify(
      BuildContext context, WidgetRef ref, Prescriber p) async {
    final ok = await ref
        .read(consultationNotifierProvider.notifier)
        .notifyTotal(p.id);
    if (!context.mounted) return;
    _snack(
        context,
        ok,
        ok
            ? 'Total consultation fees sent to Dr. ${p.name} and admin'
            : 'Failed to send notification');
  }

  Future<void> _payAll(BuildContext context, WidgetRef ref,
      ConsultationPayoutSummary s, Prescriber p) async {
    final confirm = await _confirm(
      context,
      'Pay All Pending',
      'Settle all ${s.pendingCount} pending consultation payout(s) totalling '
          'NGN ${_fmt.format(s.pendingAmount)} to Dr. ${p.name}? '
          'Dr. ${p.name} and the org-admin will be notified of the total.',
    );
    if (confirm != true || !context.mounted) return;
    final result = await ref
        .read(consultationNotifierProvider.notifier)
        .markAllPaid(p.id);
    if (!context.mounted) return;
    _snack(
        context,
        result != null,
        result != null
            ? '${result.$1} payout(s) settled (NGN ${_fmt.format(result.$2)}) · notified'
            : 'Failed to process payment');
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref,
      ConsultationPayout c, Prescriber p) async {
    final confirm = await _confirm(
      context,
      'Mark as Paid',
      'Record NGN ${_fmt.format(c.consultationFee)} consultation fee for '
          '${c.patientName}\'s prescription as paid out to Dr. ${c.prescriberName}?',
    );
    if (confirm != true || !context.mounted) return;
    final ok = await ref
        .read(consultationNotifierProvider.notifier)
        .markPaid(p.id, c.id);
    if (!context.mounted) return;
    _snack(context, ok,
        ok ? 'Consultation fee marked as paid' : 'Failed to update');
  }

  Future<bool?> _confirm(
      BuildContext context, String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(color: context.labelColor, fontSize: 16)),
        content: Text(body,
            style: TextStyle(color: context.subLabelColor, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: context.subLabelColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.successGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sublabel;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.sublabel,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: context.subLabelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 4),
              Text(value,
                  style: GoogleFonts.outfit(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              if (sublabel != null)
                Text(sublabel!,
                    style: TextStyle(
                        color: context.subLabelColor, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payout list tile ──────────────────────────────────────────────────────────

class _PayoutTile extends StatelessWidget {
  final ConsultationPayout payout;
  final VoidCallback? onMarkPaid;

  const _PayoutTile({required this.payout, this.onMarkPaid});

  @override
  Widget build(BuildContext context) {
    final c = payout;
    final statusColor =
        c.isPaid ? EnhancedTheme.successGreen : EnhancedTheme.warningAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
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
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      color: EnhancedTheme.accentCyan, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.patientName,
                        style: TextStyle(
                            color: context.labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Rx #${c.prescriptionId}  ·  ${c.createdAt}',
                        style: TextStyle(
                            color: context.subLabelColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    c.isPaid ? 'Paid' : 'Pending',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (c.category != null && c.category!.isNotEmpty) ...[
                  _Stat(label: 'Category', value: c.category!),
                  const SizedBox(width: 16),
                ],
                _Stat(
                  label: 'Consultation Fee',
                  value: 'NGN ${_fmt.format(c.consultationFee)}',
                  highlight: true,
                ),
                if (onMarkPaid != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: onMarkPaid,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            EnhancedTheme.successGreen,
                            EnhancedTheme.primaryTeal
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Pay Out',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Stat(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.subLabelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: highlight
                      ? EnhancedTheme.accentCyan
                      : context.labelColor,
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w600)),
        ],
      );
}
