import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';

class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  String _fmtValue(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inventoryReportProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => context.pop()),
              const SizedBox(width: 4),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Inventory Report',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Stock levels & valuation',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: () => ref.invalidate(inventoryReportProvider)),
            ]),
          ),

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
              TextButton(
                onPressed: () => ref.invalidate(inventoryReportProvider),
                child: const Text('Retry',
                    style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, InventoryReportData data) {
    final summaryItems = [
      {'label': 'Total Items',   'value': '${data.totalItems}',        'color': EnhancedTheme.primaryTeal,  'icon': Icons.inventory_2_rounded},
      {'label': 'Low Stock',     'value': '${data.lowStockCount}',     'color': EnhancedTheme.warningAmber, 'icon': Icons.warning_amber_rounded},
      {'label': 'Stock Value',   'value': _fmtValue(data.stockValue),  'color': EnhancedTheme.accentCyan,   'icon': Icons.account_balance_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Summary grid ─────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10,
              crossAxisSpacing: 10, childAspectRatio: 1.3),
          itemCount: summaryItems.length,
          itemBuilder: (_, i) {
            final s     = summaryItems[i];
            final color = s['color'] as Color;
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.25))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(s['icon'] as IconData, color: color, size: 18),
                    const SizedBox(height: 4),
                    Text(s['value'] as String,
                        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(s['label'] as String,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Low stock alerts ─────────────────────────────────────────────────
        Row(children: [
          const Expanded(child: Text('Low Stock Alerts',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6)),
            child: Text('${data.lowStockItems.length} items',
                style: const TextStyle(color: EnhancedTheme.warningAmber,
                    fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        if (data.lowStockItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('All items adequately stocked',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
        else
          ...data.lowStockItems.map(_lowStockRow),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _lowStockRow(LowStockItem item) {
    final pct = item.lowStockThreshold > 0
        ? item.stock / item.lowStockThreshold
        : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EnhancedTheme.warningAmber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: EnhancedTheme.warningAmber, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      pct < 0.3 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber),
                  minHeight: 4),
              ),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${item.stock}',
                  style: const TextStyle(color: EnhancedTheme.warningAmber,
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text('threshold: ${item.lowStockThreshold}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}
