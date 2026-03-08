import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';

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
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
                  onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Profit Report',
                    style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Revenue, cost & margin analysis',
                    style: TextStyle(color: context.hintColor, fontSize: 11)),
              ])),
            ]),
          ),

          // Period selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: _periods.map((p) {
              final active = p == _period;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _period = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? EnhancedTheme.successGreen
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(p, textAlign: TextAlign.center,
                      style: TextStyle(
                          color: active ? Colors.white : Colors.white54,
                          fontSize: 10, fontWeight: FontWeight.w600))),
              ));
            }).toList()),
          ),

          Expanded(child: reportAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: EnhancedTheme.successGreen)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('$e',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(profitReportProvider(_apiPeriod)),
                child: const Text('Retry',
                    style: TextStyle(color: EnhancedTheme.successGreen))),
            ])),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, ProfitReportData data) {
    final maxCatRev = data.byCategory.isEmpty
        ? 1.0
        : data.byCategory.map((c) => c.revenue).fold(1.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── P&L summary cards ─────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _plCard(context, 'Revenue', _fmt(data.revenue),
              EnhancedTheme.primaryTeal, Icons.trending_up_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _plCard(context, 'Cost', _fmt(data.cost),
              EnhancedTheme.errorRed, Icons.trending_down_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _plCard(context, 'Profit', _fmt(data.grossProfit),
              EnhancedTheme.successGreen, Icons.savings_rounded)),
        ]),
        const SizedBox(height: 10),

        // ── Net margin card ───────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: EnhancedTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: EnhancedTheme.successGreen.withValues(alpha: 0.25))),
              child: Row(children: [
                const Icon(Icons.percent_rounded,
                    color: EnhancedTheme.successGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Net Profit Margin',
                      style: TextStyle(color: context.labelColor,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('For the selected period',
                      style: TextStyle(
                          color: context.hintColor, fontSize: 11)),
                ])),
                Text('${(data.netMargin * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: EnhancedTheme.successGreen,
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Revenue vs Cost by category chart ─────────────────────────────────
        if (data.byCategory.isNotEmpty) ...[
          Text('Revenue vs Cost by Category',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor)),
                child: Column(children: [
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data.byCategory.map((c) {
                        final revH  = (c.revenue / maxCatRev) * 120;
                        final costH = (c.cost    / maxCatRev) * 120;
                        return Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text(_fmt(c.revenue - c.cost),
                                style: TextStyle(
                                    color: EnhancedTheme.successGreen.withValues(alpha: 0.7),
                                    fontSize: 7)),
                            const SizedBox(height: 2),
                            Stack(alignment: Alignment.bottomCenter, children: [
                              Container(height: revH,
                                decoration: BoxDecoration(
                                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)))),
                              Container(height: costH,
                                decoration: BoxDecoration(
                                  color: EnhancedTheme.errorRed.withValues(alpha: 0.5),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3)))),
                            ]),
                          ]),
                        ));
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: data.byCategory.map((c) => Expanded(
                    child: Text(c.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.subLabelColor, fontSize: 8)),
                  )).toList()),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _legend(context, EnhancedTheme.primaryTeal.withValues(alpha: 0.6), 'Revenue'),
                    const SizedBox(width: 16),
                    _legend(context, EnhancedTheme.errorRed.withValues(alpha: 0.7), 'Cost'),
                    const SizedBox(width: 16),
                    _legend(context, EnhancedTheme.successGreen, 'Profit'),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Margin by category ────────────────────────────────────────────────
        Text('Margin by Category',
            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (data.byCategory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No category data',
                style: TextStyle(color: context.hintColor)))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor)),
                child: Column(
                  children: data.byCategory.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      SizedBox(width: 90, child: Text(c.name,
                          style: TextStyle(color: context.labelColor,
                              fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.margin.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              c.margin > 0.4
                                  ? EnhancedTheme.successGreen
                                  : EnhancedTheme.primaryTeal),
                          minHeight: 8),
                      )),
                      const SizedBox(width: 10),
                      Text('${(c.margin * 100).round()}%',
                          style: TextStyle(color: context.labelColor,
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  )).toList(),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _plCard(BuildContext context, String label, String value, Color color, IconData icon) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Column(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(color: context.hintColor, fontSize: 9)),
            ]),
          ),
        ),
      );

  Widget _legend(BuildContext context, Color color, String label) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label,
        style: TextStyle(color: context.subLabelColor, fontSize: 10)),
  ]);
}
