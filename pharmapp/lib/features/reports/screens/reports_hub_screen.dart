import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';

class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  static const _reports = [
    {
      'title':  'Sales Report',
      'sub':    'Revenue, transactions & top-selling items',
      'icon':   Icons.bar_chart_rounded,
      'color':  EnhancedTheme.primaryTeal,
      'route':  '/dashboard/reports/sales',
    },
    {
      'title':  'Inventory Report',
      'sub':    'Stock levels, categories & expiry alerts',
      'icon':   Icons.inventory_2_rounded,
      'color':  EnhancedTheme.accentCyan,
      'route':  '/dashboard/reports/inventory',
    },
    {
      'title':  'Customer Report',
      'sub':    'Customer analytics & outstanding debts',
      'icon':   Icons.people_rounded,
      'color':  EnhancedTheme.accentPurple,
      'route':  '/dashboard/reports/customers',
    },
    {
      'title':  'Profit Report',
      'sub':    'Revenue vs cost, margins by category',
      'icon':   Icons.savings_rounded,
      'color':  EnhancedTheme.successGreen,
      'route':  '/dashboard/reports/profit',
    },
  ];

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync   = ref.watch(salesReportProvider('today'));
    final salesMonthly = ref.watch(salesReportProvider('month'));
    final profitAsync  = ref.watch(profitReportProvider('month'));
    final custAsync    = ref.watch(customerReportProvider);

    final todayRevenue   = salesAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final monthRevenue   = salesMonthly.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final netMargin      = profitAsync.whenOrNull(data: (d) => d.margin) ?? 0.0;
    final outstanding    = custAsync.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final isLoading      = salesAsync.isLoading || profitAsync.isLoading || custAsync.isLoading;

    final kpis = [
      {'label': "Today's Revenue", 'value': isLoading ? '…' : _fmt(todayRevenue), 'color': EnhancedTheme.primaryTeal},
      {'label': 'This Month',      'value': isLoading ? '…' : _fmt(monthRevenue),  'color': EnhancedTheme.accentCyan},
      {'label': 'Net Margin',      'value': isLoading ? '…' : '${netMargin.toStringAsFixed(1)}%', 'color': EnhancedTheme.successGreen},
      {'label': 'Outstanding',     'value': isLoading ? '…' : _fmt(outstanding),   'color': EnhancedTheme.errorRed},
    ];

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(child: Column(children: [

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Reports', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                  Text('Analytics & business insights', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
              ]),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // KPI row — live data
                Row(children: kpis.map((k) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: (k['color'] as Color).withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: (k['color'] as Color).withValues(alpha:0.25)),
                        ),
                        child: Column(children: [
                          isLoading
                              ? SizedBox(height: 16,
                                  child: LinearProgressIndicator(
                                      color: k['color'] as Color,
                                      backgroundColor: (k['color'] as Color).withValues(alpha: 0.1)))
                              : Text(k['value'] as String, style: TextStyle(
                                  color: k['color'] as Color, fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(k['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.hintColor, fontSize: 9)),
                        ]),
                      ),
                    ),
                  ),
                ))).toList()),
                const SizedBox(height: 24),

                Text('Select Report', style: TextStyle(
                    color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Report cards
                ..._reports.map((r) => _ReportCard(
                  title: r['title'] as String,
                  subtitle: r['sub'] as String,
                  icon: r['icon'] as IconData,
                  color: r['color'] as Color,
                  onTap: () => context.push(r['route'] as String),
                )),
                const SizedBox(height: 32),
              ]),
            )),
          ])),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PressableReportCard(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha:0.2)),
              ),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(
                      color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(
                      color: context.subLabelColor, fontSize: 12)),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha:0.6), size: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableReportCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableReportCard({required this.child, required this.onTap});

  @override
  State<_PressableReportCard> createState() => _PressableReportCardState();
}

class _PressableReportCardState extends State<_PressableReportCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
