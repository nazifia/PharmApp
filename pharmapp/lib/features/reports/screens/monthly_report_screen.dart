import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyReportProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, DateTime>((ref, month) {
  return ref.watch(posApiProvider).fetchMonthlyReport(
        month: month.month,
        year: month.year,
      );
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MonthlyReportScreen extends ConsumerWidget {
  const MonthlyReportScreen({super.key});

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected   = ref.watch(_selectedMonthProvider);
    final reportAsync = ref.watch(monthlyReportProvider(selected));
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Monthly Report',
                    style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Sales, expenses & net profit',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Month selector ──────────────────────────────────────────
              _monthSelector(context, ref, selected, now),
              const SizedBox(height: 20),

              // ── Report data ─────────────────────────────────────────────
              reportAsync.when(
                loading: () => Column(children: [
                  EnhancedTheme.loadingShimmer(height: 110, radius: 16),
                  const SizedBox(height: 12),
                  EnhancedTheme.loadingShimmer(height: 110, radius: 16),
                  const SizedBox(height: 12),
                  EnhancedTheme.loadingShimmer(height: 110, radius: 16),
                ]),
                error: (e, _) => _errorCard(context, '$e'),
                data: (data) => _reportContent(context, data),
              ),
              const SizedBox(height: 32),
            ]),
          )),
        ])),
      ]),
    );
  }

  // ── Month selector ─────────────────────────────────────────────────────────

  Widget _monthSelector(BuildContext context, WidgetRef ref, DateTime selected, DateTime now) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            // Previous month
            GestureDetector(
              onTap: () {
                final prev = DateTime(selected.year, selected.month - 1);
                ref.read(_selectedMonthProvider.notifier).state = prev;
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: EnhancedTheme.primaryTeal, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [
              Text('${_monthNames[selected.month - 1]} ${selected.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
              if (selected.year == now.year && selected.month == now.month)
                Text('Current Month',
                    style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11)),
            ])),
            const SizedBox(width: 12),
            // Next month (disable if future)
            GestureDetector(
              onTap: selected.year < now.year ||
                      (selected.year == now.year && selected.month < now.month)
                  ? () {
                      final next = DateTime(selected.year, selected.month + 1);
                      ref.read(_selectedMonthProvider.notifier).state = next;
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (selected.year < now.year ||
                          (selected.year == now.year && selected.month < now.month))
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.1)
                      : context.cardColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (selected.year < now.year ||
                            (selected.year == now.year && selected.month < now.month))
                        ? EnhancedTheme.primaryTeal.withValues(alpha: 0.25)
                        : context.borderColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: (selected.year < now.year ||
                            (selected.year == now.year && selected.month < now.month))
                        ? EnhancedTheme.primaryTeal
                        : context.hintColor,
                    size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Report content ─────────────────────────────────────────────────────────

  Widget _reportContent(BuildContext context, Map<String, dynamic> data) {
    final totalSales    = (data['totalSales']    as num?)?.toDouble() ?? 0;
    final totalExpenses = (data['totalExpenses'] as num?)?.toDouble() ?? 0;
    final netProfit     = (data['netProfit']     as num?)?.toDouble() ?? 0;
    final isProfit      = netProfit >= 0;

    return Column(children: [

      // ── Summary cards ───────────────────────────────────────────────────
      Row(children: [
        Expanded(child: _kpiCard(context, 'Total Sales', _fmtNaira(totalSales),
            Icons.trending_up_rounded, EnhancedTheme.successGreen)),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(context, 'Total Expenses', _fmtNaira(totalExpenses),
            Icons.money_off_rounded, EnhancedTheme.warningAmber)),
      ]),
      const SizedBox(height: 12),

      // ── Net Profit card ─────────────────────────────────────────────────
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: (isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isProfit ? Icons.savings_rounded : Icons.show_chart_rounded,
                  color: isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Net Profit',
                    style: TextStyle(color: context.hintColor, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_fmtNaira(netProfit.abs()),
                    style: TextStyle(
                      color: isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                      fontSize: 26, fontWeight: FontWeight.w800)),
                Text(isProfit ? 'Profit this month' : 'Loss this month',
                    style: TextStyle(
                      color: (isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                          .withValues(alpha: 0.75),
                      fontSize: 12)),
              ])),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 20),

      // ── Breakdown ───────────────────────────────────────────────────────
      Text('Breakdown',
          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(children: [
              _breakdownRow(context, 'Total Sales Revenue',
                  _fmtNaira(totalSales), EnhancedTheme.successGreen,
                  Icons.point_of_sale_rounded),
              Divider(color: context.dividerColor, height: 20),
              _breakdownRow(context, 'Total Expenses',
                  '− ${_fmtNaira(totalExpenses)}', EnhancedTheme.warningAmber,
                  Icons.receipt_long_rounded),
              Divider(color: context.dividerColor, height: 20),
              _breakdownRow(context, 'Net Profit / Loss',
                  '${isProfit ? "" : "−"}${_fmtNaira(netProfit.abs())}',
                  isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                  isProfit ? Icons.savings_rounded : Icons.trending_down_rounded,
                  bold: true),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 20),

      // ── Visual bar ──────────────────────────────────────────────────────
      if (totalSales > 0) ...[
        Text('Revenue vs Expenses',
            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(children: [
                _barRow(context, 'Sales', totalSales, totalSales, EnhancedTheme.successGreen),
                const SizedBox(height: 12),
                _barRow(context, 'Expenses', totalExpenses, totalSales, EnhancedTheme.warningAmber),
                const SizedBox(height: 12),
                _barRow(context, 'Net Profit', netProfit.clamp(0, double.infinity) as double,
                    totalSales, EnhancedTheme.primaryTeal),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _kpiCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: context.subLabelColor, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _breakdownRow(BuildContext context, String label, String value, Color color,
      IconData icon, {bool bold = false}) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: TextStyle(
            color: bold ? context.labelColor : context.subLabelColor,
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ))),
      Text(value,
          style: TextStyle(color: color,
              fontSize: bold ? 16 : 14, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _barRow(BuildContext context, String label, double value, double maxVal, Color color) {
    final pct = maxVal > 0 ? (value / maxVal).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      SizedBox(width: 80,
          child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 14,
        ),
      )),
      const SizedBox(width: 8),
      Text('${(pct * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _errorCard(BuildContext context, String msg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: EnhancedTheme.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 13))),
        ]),
      ),
    );
  }
}
