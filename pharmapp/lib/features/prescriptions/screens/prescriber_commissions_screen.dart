import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../../../shared/models/prescriber.dart';
import '../../../shared/models/prescriber_commission.dart';
import '../providers/prescriber_provider.dart';

final _fmt = NumberFormat('#,##0.00');

class PrescriberCommissionsScreen extends ConsumerWidget {
  final Prescriber? prescriber;
  final bool isAdminView;

  const PrescriberCommissionsScreen({
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
    final summaryAsync =
        ref.watch(prescriberCommissionSummaryProvider(p.id));
    final commissionsAsync =
        ref.watch(prescriberCommissionsProvider(p.id));

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
                color: EnhancedTheme.accentOrange.withValues(alpha: 0.10),
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
                          color: EnhancedTheme.accentOrange.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.monetization_on_rounded,
                            color: EnhancedTheme.accentOrange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdminView ? 'Commission Ledger' : 'My Earnings',
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
                      if (p.commissionRate > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: EnhancedTheme.accentOrange
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${p.commissionRate.toStringAsFixed(p.commissionRate % 1 == 0 ? 0 : 1)}% rate',
                            style: const TextStyle(
                                color: EnhancedTheme.accentOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (isAdminView) ...[
                        const SizedBox(width: 8),
                        summaryAsync.maybeWhen(
                          data: (s) => s.pendingCount > 0
                              ? GestureDetector(
                                  onTap: () => _payAll(context, ref, s, p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          EnhancedTheme.successGreen,
                                          EnhancedTheme.primaryTeal,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
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
                            color: EnhancedTheme.accentOrange)),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                            child: _SummaryCard(
                          label: 'Total Earned',
                          value: 'NGN ${_fmt.format(s.totalEarned)}',
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

                // ── Filter tabs + list ────────────────────────────────────
                Expanded(
                  child: commissionsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.accentOrange)),
                    error: (e, _) => Center(
                      child: Text('Error loading commissions: $e',
                          style:
                              TextStyle(color: context.subLabelColor, fontSize: 13)),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 64,
                                  color: context.iconOnBg.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No commission records yet',
                                style: TextStyle(
                                    color: context.hintColor, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Commissions are created when\nprescribed medications are dispensed.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: context.subLabelColor, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _CommissionTile(
                          commission: list[i],
                          isAdminView: isAdminView,
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

  Future<void> _payAll(
      BuildContext context, WidgetRef ref, CommissionSummary s, Prescriber p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pay All Pending',
            style: TextStyle(color: context.labelColor, fontSize: 16)),
        content: Text(
          'Mark all ${s.pendingCount} pending commission(s) totalling NGN ${_fmt.format(s.pendingAmount)} as paid out to Dr. ${p.name}?',
          style: TextStyle(color: context.subLabelColor, fontSize: 14),
        ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final result = await ref
        .read(commissionNotifierProvider.notifier)
        .markAllPaid(p.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result != null
            ? EnhancedTheme.successGreen.withValues(alpha: 0.92)
            : EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          result != null
              ? '${result.$1} commission(s) marked as paid (NGN ${_fmt.format(result.$2)})'
              : 'Failed to process payment',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _markPaid(
      BuildContext context, WidgetRef ref, PrescriberCommission c, Prescriber p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark as Paid',
            style: TextStyle(color: context.labelColor, fontSize: 16)),
        content: Text(
          'Record NGN ${_fmt.format(c.commissionAmount)} commission for ${c.patientName}\'s prescription as paid out to Dr. ${c.prescriberName}?',
          style: TextStyle(color: context.subLabelColor, fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style:
                      TextStyle(color: context.subLabelColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.successGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    final ok = await ref
        .read(commissionNotifierProvider.notifier)
        .markPaid(p.id, c.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok
            ? EnhancedTheme.successGreen.withValues(alpha: 0.92)
            : EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          ok ? 'Commission marked as paid' : 'Failed to update',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
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

// ── Commission list tile ──────────────────────────────────────────────────────

class _CommissionTile extends StatelessWidget {
  final PrescriberCommission commission;
  final bool isAdminView;
  final VoidCallback? onMarkPaid;

  const _CommissionTile({
    required this.commission,
    required this.isAdminView,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final c = commission;
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
                    color: EnhancedTheme.accentOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_rounded,
                      color: EnhancedTheme.accentOrange, size: 16),
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
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4)),
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
                _Stat(
                    label: 'Sales Value',
                    value: 'NGN ${_fmt.format(c.salesAmount)}'),
                const SizedBox(width: 16),
                _Stat(
                    label: 'Rate',
                    value:
                        '${c.commissionRate.toStringAsFixed(c.commissionRate % 1 == 0 ? 0 : 1)}%'),
                const SizedBox(width: 16),
                _Stat(
                  label: 'Commission',
                  value: 'NGN ${_fmt.format(c.commissionAmount)}',
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
  const _Stat({required this.label, required this.value, this.highlight = false});

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
                      ? EnhancedTheme.accentOrange
                      : context.labelColor,
                  fontSize: 13,
                  fontWeight:
                      highlight ? FontWeight.w700 : FontWeight.w600)),
        ],
      );
}
