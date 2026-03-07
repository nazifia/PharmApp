import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockSummary = [
      {'label': 'Total SKUs',    'value': '312',      'color': EnhancedTheme.primaryTeal,  'icon': Icons.inventory_2_rounded},
      {'label': 'Low Stock',     'value': '7',        'color': EnhancedTheme.warningAmber, 'icon': Icons.warning_amber_rounded},
      {'label': 'Out of Stock',  'value': '2',        'color': EnhancedTheme.errorRed,     'icon': Icons.remove_shopping_cart_rounded},
      {'label': 'Expiring Soon', 'value': '5',        'color': EnhancedTheme.accentOrange, 'icon': Icons.event_busy_rounded},
      {'label': 'Stock Value',   'value': '₹8.4L',   'color': EnhancedTheme.accentCyan,   'icon': Icons.account_balance_rounded},
      {'label': 'Categories',    'value': '18',       'color': EnhancedTheme.accentPurple, 'icon': Icons.category_rounded},
    ];

    final categories = [
      {'name': 'Analgesics',        'skus': 42, 'value': 125000.0, 'pct': 0.15},
      {'name': 'Antibiotics',       'skus': 38, 'value': 210000.0, 'pct': 0.25},
      {'name': 'Vitamins & Suppl.', 'skus': 55, 'value': 185000.0, 'pct': 0.22},
      {'name': 'Antidiabetics',     'skus': 28, 'value': 140000.0, 'pct': 0.17},
      {'name': 'Cardiovascular',    'skus': 31, 'value': 175000.0, 'pct': 0.21},
    ];

    final lowStockItems = [
      {'name': 'Paracetamol 500mg',  'stock': 5,  'low': 20, 'reorder': 100},
      {'name': 'Amoxicillin 250mg',  'stock': 3,  'low': 15, 'reorder': 50},
      {'name': 'Omeprazole 20mg',    'stock': 2,  'low': 10, 'reorder': 40},
      {'name': 'Metformin 500mg',    'stock': 8,  'low': 25, 'reorder': 80},
      {'name': 'Salbutamol Inhaler', 'stock': 6,  'low': 10, 'reorder': 20},
    ];

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
                const SizedBox(width: 4),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Inventory Report', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Stock levels & valuation', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
              ]),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Summary grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3),
                  itemCount: stockSummary.length,
                  itemBuilder: (_, i) {
                    final s = stockSummary[i];
                    final color = s['color'] as Color;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(s['icon'] as IconData, color: color, size: 18),
                            const SizedBox(height: 4),
                            Text(s['value'] as String, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                            Text(s['label'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9), textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Category breakdown
                const Text('Stock by Category', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: categories.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(c['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
                              Text('${c['skus']} SKUs', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                              const SizedBox(width: 10),
                              Text('₹${((c['value'] as double) / 1000).toStringAsFixed(0)}K',
                                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: c['pct'] as double,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(EnhancedTheme.primaryTeal),
                                minHeight: 6,
                              ),
                            ),
                          ]),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Low stock
                Row(children: [
                  const Expanded(child: Text('Low Stock Alerts', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: EnhancedTheme.warningAmber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('${lowStockItems.length} items', style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                ...lowStockItems.map((item) => _lowStockRow(item)),
                const SizedBox(height: 24),
              ]),
            )),
          ])),
        ],
      ),
    );
  }

  Widget _lowStockRow(Map<String, dynamic> item) {
    final stock = item['stock'] as int;
    final low   = item['low'] as int;
    final pct   = stock / low;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EnhancedTheme.warningAmber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnhancedTheme.warningAmber.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.warningAmber, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct < 0.3 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber),
                  minHeight: 4,
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$stock / $low', style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('reorder: ${item['reorder']}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}
