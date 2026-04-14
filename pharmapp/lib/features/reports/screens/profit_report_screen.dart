import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';
import '../shared/report_exporter.dart';

class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  String _period = 'This Month';
  final _periods = ['This Week', 'This Month', 'This Quarter', 'This Year'];

  String get _apiPeriod {
    switch (_period) {
      case 'This Week':    return 'week';
      case 'This Quarter': return 'quarter';
      case 'This Year':    return 'year';
      default:             return 'month';
    }
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(profitReportProvider(_apiPeriod));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative glow
        Positioned(top: -40, left: -60,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.successGreen.withValues(alpha: 0.14),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(bottom: 80, right: -60,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.accentCyan.withValues(alpha: 0.10),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          _buildHeader(context, reportAsync.valueOrNull),

          // ── Period pill selector ───────────────────────────────────────────
          _buildPeriodSelector(),

          Expanded(child: reportAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                EnhancedTheme.loadingShimmer(height: 110, radius: 20),
                const SizedBox(height: 12),
                EnhancedTheme.loadingShimmer(height: 100, radius: 20),
                const SizedBox(height: 12),
                EnhancedTheme.loadingShimmer(height: 160, radius: 20),
              ]),
            ),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded,
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.6), size: 36),
              ),
              const SizedBox(height: 16),
              Text('Failed to load report',
                  style: GoogleFonts.outfit(
                      color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('$e',
                  style: GoogleFonts.inter(
                      color: context.subLabelColor, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(profitReportProvider(_apiPeriod)),
                icon: const Icon(Icons.refresh_rounded, color: EnhancedTheme.successGreen, size: 18),
                label: const Text('Retry', style: TextStyle(color: EnhancedTheme.successGreen)),
              ),
            ])),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, ProfitReportData? reportData) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
            onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profit Report',
              style: GoogleFonts.outfit(
                  color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w700)),
          Text('Revenue, cost & margin analysis',
              style: GoogleFonts.inter(color: context.hintColor, fontSize: 12)),
        ])),
        // Export button
        Builder(builder: (ctx) {
          final hasExport = ref.watch(hasFeatureProvider(SaasFeature.exportData));
          return GestureDetector(
            onTap: () async {
              if (!hasExport) { ctx.go('/subscription'); return; }
              if (reportData == null) return;
              await ReportExporter.exportProfitReport(reportData, _period);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: hasExport
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasExport
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(
                hasExport ? Icons.download_rounded : Icons.lock_rounded,
                color: hasExport ? EnhancedTheme.primaryTeal : Colors.white38,
                size: 18),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EnhancedTheme.successGreen.withValues(alpha: 0.2),
              EnhancedTheme.successGreen.withValues(alpha: 0.08),
            ]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bar_chart_rounded, color: EnhancedTheme.successGreen, size: 14),
            const SizedBox(width: 6),
            Text(_period.split(' ').last,
                style: GoogleFonts.inter(
                    color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.2);
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: _periods.map((p) {
              final active = p == _period;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _period = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: active ? LinearGradient(
                      colors: [EnhancedTheme.successGreen, EnhancedTheme.successGreen.withValues(alpha: 0.8)],
                    ) : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: active ? [
                      BoxShadow(
                        color: EnhancedTheme.successGreen.withValues(alpha: 0.4),
                        blurRadius: 8, offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Text(p, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: active ? Colors.black : context.subLabelColor,
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ));
            }).toList()),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _buildBody(BuildContext context, ProfitReportData data) {
    final cost = data.revenue > 0 ? data.revenue - data.profit : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── P&L Hero Cards ────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _plCard(context, 'Revenue', _fmt(data.revenue),
              EnhancedTheme.primaryTeal, Icons.trending_up_rounded, 'Gross income')
              .animate().fadeIn(delay: 100.ms).slideY(begin: 0.2)),
          const SizedBox(width: 10),
          Expanded(child: _plCard(context, 'Cost', _fmt(cost),
              EnhancedTheme.errorRed, Icons.trending_down_rounded, 'Cost of goods')
              .animate().fadeIn(delay: 180.ms).slideY(begin: 0.2)),
          const SizedBox(width: 10),
          Expanded(child: _plCard(context, 'Profit', _fmt(data.profit),
              EnhancedTheme.successGreen, Icons.savings_rounded, 'Net earnings')
              .animate().fadeIn(delay: 260.ms).slideY(begin: 0.2)),
        ]),
        const SizedBox(height: 14),

        // ── Margin Banner ─────────────────────────────────────────────────
        _marginBanner(context, data).animate().fadeIn(delay: 320.ms).scale(begin: const Offset(0.96, 0.96)),
        const SizedBox(height: 24),

        // ── Revenue Breakdown Stacked Bar ─────────────────────────────────
        if (data.revenue > 0) ...[
          Row(children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [EnhancedTheme.errorRed, EnhancedTheme.successGreen],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Revenue Breakdown',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
          ]).animate().fadeIn(delay: 370.ms),
          const SizedBox(height: 12),
          _revenueBreakdownCard(context, data, cost)
              .animate().fadeIn(delay: 420.ms).slideY(begin: 0.1),
          const SizedBox(height: 24),
        ],

        // ── Info note ─────────────────────────────────────────────────────
        _infoNote(context, data).animate().fadeIn(delay: 470.ms),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _plCard(BuildContext context, String label, String value,
      Color color, IconData icon, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: GoogleFonts.outfit(
                    color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label,
                style: GoogleFonts.inter(
                    color: context.labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: GoogleFonts.inter(color: context.hintColor, fontSize: 9)),
          ]),
        ),
      ),
    );
  }

  Widget _marginBanner(BuildContext context, ProfitReportData data) {
    final marginColor = data.margin >= 20
        ? EnhancedTheme.successGreen
        : data.margin >= 10
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.errorRed;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                marginColor.withValues(alpha: 0.14),
                marginColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: marginColor.withValues(alpha: 0.28), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [marginColor.withValues(alpha: 0.3), marginColor.withValues(alpha: 0.15)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.percent_rounded, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Profit Margin',
                    style: GoogleFonts.outfit(
                        color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('For the selected period',
                    style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
              ])),
              Text('${data.margin.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                      color: marginColor, fontSize: 28, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            // Animated margin bar
            Stack(children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (data.margin / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [marginColor, marginColor.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: marginColor.withValues(alpha: 0.4), blurRadius: 6)],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('0%', style: GoogleFonts.inter(color: context.hintColor, fontSize: 9)),
              Text('50%', style: GoogleFonts.inter(color: context.hintColor, fontSize: 9)),
              Text('100%', style: GoogleFonts.inter(color: context.hintColor, fontSize: 9)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _revenueBreakdownCard(BuildContext context, ProfitReportData data, double cost) {
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _legend(context, EnhancedTheme.errorRed.withValues(alpha: 0.75),
                  'Cost (${((cost / data.revenue) * 100).round()}%)'),
              _legend(context, EnhancedTheme.successGreen,
                  'Profit (${data.margin.round()}%)'),
            ]),
            const SizedBox(height: 12),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 20,
                child: Row(children: [
                  Expanded(
                    flex: (cost / data.revenue * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          EnhancedTheme.errorRed.withValues(alpha: 0.8),
                          EnhancedTheme.errorRed.withValues(alpha: 0.5),
                        ]),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: (data.margin).round().clamp(1, 100),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          EnhancedTheme.successGreen,
                          Color(0xFF059669),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _barStatRow(context, 'Revenue',
                  _fmt(data.revenue), EnhancedTheme.primaryTeal)),
              Container(width: 1, height: 32, color: context.dividerColor),
              Expanded(child: _barStatRow(context, 'Cost',
                  _fmt(cost), EnhancedTheme.errorRed)),
              Container(width: 1, height: 32, color: context.dividerColor),
              Expanded(child: _barStatRow(context, 'Profit',
                  _fmt(data.profit), EnhancedTheme.successGreen)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _barStatRow(BuildContext context, String label, String value, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
    ]);
  }

  Widget _infoNote(BuildContext context, ProfitReportData data) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EnhancedTheme.accentCyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: EnhancedTheme.accentCyan, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
                data.margin > 0
                    ? 'Profit calculated from item cost prices where available.'
                    : 'No cost data available. Profit is estimated at 30% of revenue.',
                style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12))),
          ]),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(children: [
    Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    const SizedBox(width: 6),
    Text(label, style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 11, fontWeight: FontWeight.w500)),
  ]);
}
