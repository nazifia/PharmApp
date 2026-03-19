import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  String _period = 'Today';
  final _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  String get _apiPeriod {
    switch (_period) {
      case 'This Week':  return 'week';
      case 'This Month': return 'month';
      case 'This Year':  return 'year';
      default:           return 'today';
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
    final reportAsync = ref.watch(salesReportProvider(_apiPeriod));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context),
          _periodSelector(),
          Expanded(child: reportAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('$e',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(salesReportProvider(_apiPeriod)),
                child: const Text('Retry',
                    style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, SalesReportData data) {
    final grand = data.totalRevenue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Summary cards ────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _summaryCard('Total Revenue', _fmt(grand),
              EnhancedTheme.primaryTeal, Icons.trending_up_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Retail', _fmt(data.totalRetail),
              EnhancedTheme.accentCyan, Icons.storefront_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Wholesale', _fmt(data.totalWholesale),
              EnhancedTheme.accentPurple, Icons.store_rounded)),
        ]),
        const SizedBox(height: 12),

        // ── Total sales count ────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25))),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: EnhancedTheme.primaryTeal, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Total Transactions',
                    style: TextStyle(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600))),
                Text('${data.totalSales}',
                    style: const TextStyle(color: EnhancedTheme.primaryTeal,
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Retail vs Wholesale breakdown ────────────────────────────────────
        Text('Sales Breakdown',
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
              child: grand <= 0
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No data for this period',
                          style: TextStyle(color: context.subLabelColor))))
                  : Column(children: [
                      _breakdownRow('Retail', data.totalRetail, grand, EnhancedTheme.accentCyan),
                      const SizedBox(height: 12),
                      _breakdownRow('Wholesale', data.totalWholesale, grand, EnhancedTheme.accentPurple),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Top items ────────────────────────────────────────────────────────
        Text('Top Selling Items',
            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (data.topItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No data', style: TextStyle(color: context.subLabelColor)))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor)),
                child: Column(
                  children: data.topItems.asMap().entries.map((e) => Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(color: EnhancedTheme.primaryTeal,
                                  fontSize: 11, fontWeight: FontWeight.w700)))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.value.name,
                            style: TextStyle(color: context.labelColor,
                                fontSize: 13, fontWeight: FontWeight.w500))),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_fmt(e.value.revenue),
                              style: const TextStyle(color: EnhancedTheme.primaryTeal,
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('${e.value.qty} units',
                              style: TextStyle(color: context.hintColor, fontSize: 10)),
                        ]),
                      ]),
                    ),
                    if (e.key < data.topItems.length - 1)
                      Divider(height: 1, color: context.dividerColor),
                  ])).toList(),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _breakdownRow(String label, double value, double total, Color color) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w500))),
        Text('${(pct * 100).round()}%',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text(_fmt(value),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8),
      ),
    ]);
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop()),
      const SizedBox(width: 4),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sales Report',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        Text('Revenue & transaction analytics',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
      ])),
      IconButton(
        icon: const Icon(Icons.download_rounded, color: Colors.white70),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export — coming soon')))),
    ]),
  );

  Widget _periodSelector() => Padding(
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
            color: active ? EnhancedTheme.primaryTeal : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10)),
          child: Text(p, textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 11, fontWeight: FontWeight.w600))),
      ));
    }).toList()),
  );

  Widget _summaryCard(String label, String value, Color color, IconData icon) =>
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
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}
