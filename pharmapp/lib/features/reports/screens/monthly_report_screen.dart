import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

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
    final selected    = ref.watch(_selectedMonthProvider);
    final reportAsync = ref.watch(monthlyReportProvider(selected));
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative glow blobs
        Positioned(top: -60, right: -60,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(bottom: 100, left: -80,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.successGreen.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(context, ref),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Month selector ──────────────────────────────────────────
              _monthSelector(context, ref, selected, now)
                  .animate().fadeIn(duration: 400.ms).slideY(begin: -0.15),
              const SizedBox(height: 20),

              // ── Report data ─────────────────────────────────────────────
              reportAsync.when(
                loading: () => Column(children: [
                  EnhancedTheme.loadingShimmer(height: 130, radius: 20),
                  const SizedBox(height: 12),
                  EnhancedTheme.loadingShimmer(height: 130, radius: 20),
                  const SizedBox(height: 12),
                  EnhancedTheme.loadingShimmer(height: 200, radius: 20),
                ]),
                error: (e, _) => _errorCard(context, '$e'),
                data: (data) => _reportContent(context, data),
              ),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
            onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Monthly Report',
              style: GoogleFonts.outfit(
                  color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w700)),
          Text('Sales, expenses & net profit',
              style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
              EnhancedTheme.accentCyan.withValues(alpha: 0.12),
            ]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_rounded, color: EnhancedTheme.primaryTeal, size: 14),
            const SizedBox(width: 6),
            Text('Monthly', style: GoogleFonts.inter(
                color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.2);
  }

  // ── Month selector ─────────────────────────────────────────────────────────

  Widget _monthSelector(BuildContext context, WidgetRef ref, DateTime selected, DateTime now) {
    final canGoNext = selected.year < now.year ||
        (selected.year == now.year && selected.month < now.month);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            // Previous month
            GestureDetector(
              onTap: () {
                final prev = DateTime(selected.year, selected.month - 1);
                ref.read(_selectedMonthProvider.notifier).state = prev;
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: EnhancedTheme.primaryTeal, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(children: [
              Text(_monthNames[selected.month - 1],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${selected.year}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: context.subLabelColor, fontSize: 13, fontWeight: FontWeight.w500)),
              if (selected.year == now.year && selected.month == now.month) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Current Month',
                      style: GoogleFonts.inter(
                          color: EnhancedTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ])),
            const SizedBox(width: 16),
            // Next month (disable if future)
            GestureDetector(
              onTap: canGoNext
                  ? () {
                      final next = DateTime(selected.year, selected.month + 1);
                      ref.read(_selectedMonthProvider.notifier).state = next;
                    }
                  : null,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: canGoNext
                      ? LinearGradient(colors: [
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                        ])
                      : LinearGradient(colors: [
                          context.cardColor.withValues(alpha: 0.5),
                          context.cardColor.withValues(alpha: 0.3),
                        ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canGoNext
                        ? EnhancedTheme.primaryTeal.withValues(alpha: 0.3)
                        : context.borderColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: canGoNext ? EnhancedTheme.primaryTeal : context.hintColor,
                    size: 22),
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

      // ── KPI Summary Cards ────────────────────────────────────────────────
      Row(children: [
        Expanded(child: _kpiCard(context, 'Total Sales', _fmtNaira(totalSales),
            Icons.trending_up_rounded, EnhancedTheme.successGreen,
            'Revenue generated').animate().fadeIn(delay: 100.ms).slideY(begin: 0.2)),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(context, 'Expenses', _fmtNaira(totalExpenses),
            Icons.money_off_rounded, EnhancedTheme.warningAmber,
            'Total outflows').animate().fadeIn(delay: 200.ms).slideY(begin: 0.2)),
      ]),
      const SizedBox(height: 12),

      // ── Net Profit Banner ────────────────────────────────────────────────
      _netProfitCard(context, netProfit, isProfit)
          .animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.96, 0.96)),
      const SizedBox(height: 24),

      // ── Breakdown Section ────────────────────────────────────────────────
      Row(children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text('Breakdown',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
      ]).animate().fadeIn(delay: 350.ms),
      const SizedBox(height: 12),
      _breakdownCard(context, totalSales, totalExpenses, netProfit, isProfit)
          .animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
      const SizedBox(height: 24),

      // ── Visual Bar Chart ─────────────────────────────────────────────────
      if (totalSales > 0) ...[
        Row(children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text('Revenue vs Expenses',
              style: GoogleFonts.outfit(
                  color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
        ]).animate().fadeIn(delay: 450.ms),
        const SizedBox(height: 12),
        _barChartCard(context, totalSales, totalExpenses, netProfit)
            .animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
      ],
    ]);
  }

  Widget _kpiCard(BuildContext context, String label, String value,
      IconData icon, Color color, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.arrow_outward_rounded, color: color.withValues(alpha: 0.5), size: 14),
            ]),
            const SizedBox(height: 14),
            Text(value,
                style: GoogleFonts.outfit(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    color: context.labelColor, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 10)),
          ]),
        ),
      ),
    );
  }

  Widget _netProfitCard(BuildContext context, double netProfit, bool isProfit) {
    final color = isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isProfit ? Icons.savings_rounded : Icons.show_chart_rounded,
                color: color, size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isProfit ? 'Net Profit' : 'Net Loss',
                  style: GoogleFonts.inter(
                      color: context.hintColor, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(_fmtNaira(netProfit.abs()),
                  style: GoogleFonts.outfit(
                      color: color, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(
                  isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: color.withValues(alpha: 0.8), size: 14,
                ),
                const SizedBox(width: 4),
                Text(isProfit ? 'Profitable this month' : 'Loss this month',
                    style: GoogleFonts.inter(
                        color: color.withValues(alpha: 0.8), fontSize: 12)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _breakdownCard(BuildContext context, double totalSales,
      double totalExpenses, double netProfit, bool isProfit) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: [
            _breakdownRow(context, 'Total Sales Revenue',
                _fmtNaira(totalSales), EnhancedTheme.successGreen,
                Icons.point_of_sale_rounded),
            _breakdownDivider(context),
            _breakdownRow(context, 'Total Expenses',
                '− ${_fmtNaira(totalExpenses)}', EnhancedTheme.warningAmber,
                Icons.receipt_long_rounded),
            _breakdownDivider(context),
            _breakdownRow(context, 'Net Profit / Loss',
                '${isProfit ? "" : "−"}${_fmtNaira(netProfit.abs())}',
                isProfit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                isProfit ? Icons.savings_rounded : Icons.trending_down_rounded,
                bold: true),
          ]),
        ),
      ),
    );
  }

  Widget _breakdownDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Container(height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                context.dividerColor,
                Colors.transparent,
              ]),
            ))),
      ]),
    );
  }

  Widget _barChartCard(BuildContext context, double totalSales,
      double totalExpenses, double netProfit) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: [
            _animatedBarRow(context, 'Sales', totalSales, totalSales, EnhancedTheme.successGreen),
            const SizedBox(height: 14),
            _animatedBarRow(context, 'Expenses', totalExpenses, totalSales, EnhancedTheme.warningAmber),
            const SizedBox(height: 14),
            _animatedBarRow(context, 'Net', netProfit.clamp(0, double.infinity) as double,
                totalSales, EnhancedTheme.primaryTeal),
          ]),
        ),
      ),
    );
  }

  Widget _breakdownRow(BuildContext context, String label, String value, Color color,
      IconData icon, {bool bold = false}) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Text(label,
          style: GoogleFonts.inter(
            color: bold ? context.labelColor : context.subLabelColor,
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ))),
      Text(value,
          style: GoogleFonts.outfit(
              color: color, fontSize: bold ? 17 : 14, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _animatedBarRow(BuildContext context, String label, double value, double maxVal, Color color) {
    final pct = maxVal > 0 ? (value / maxVal).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      SizedBox(
        width: 70,
        child: Text(label,
            style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Stack(children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        FractionallySizedBox(
          widthFactor: pct,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
            ),
          ),
        ),
      ])),
      const SizedBox(width: 10),
      Text('${(pct * 100).toStringAsFixed(0)}%',
          style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _errorCard(BuildContext context, String msg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.error_outline_rounded, color: EnhancedTheme.errorRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Could not load report',
                style: GoogleFonts.inter(
                    color: EnhancedTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(msg,
                style: GoogleFonts.inter(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.7), fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}
