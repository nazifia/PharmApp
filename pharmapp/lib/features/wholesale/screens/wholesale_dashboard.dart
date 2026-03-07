import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class WholesaleDashboard extends ConsumerWidget {
  const WholesaleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = [
      {'label': 'Today\'s Orders', 'value': '12', 'icon': Icons.shopping_cart_rounded, 'color': EnhancedTheme.primaryTeal},
      {'label': 'Revenue',         'value': '₹84,500', 'icon': Icons.trending_up_rounded,    'color': EnhancedTheme.successGreen},
      {'label': 'Pending',         'value': '3',    'icon': Icons.pending_rounded,           'color': EnhancedTheme.warningAmber},
      {'label': 'Customers',       'value': '28',   'icon': Icons.store_rounded,             'color': EnhancedTheme.accentCyan},
    ];

    final recentOrders = [
      {'id': 'WO-1042', 'customer': 'City Pharmacy',    'items': 8,  'total': 18500.0, 'status': 'Delivered', 'date': 'Today'},
      {'id': 'WO-1041', 'customer': 'Sunrise Medical',  'items': 5,  'total': 9200.0,  'status': 'Processing','date': 'Today'},
      {'id': 'WO-1040', 'customer': 'Green Cross Clinic','items': 12, 'total': 24000.0, 'status': 'Delivered', 'date': 'Yesterday'},
      {'id': 'WO-1039', 'customer': 'Medicare Hub',     'items': 3,  'total': 6500.0,  'status': 'Pending',   'date': 'Yesterday'},
      {'id': 'WO-1038', 'customer': 'Alpha Healthcare', 'items': 9,  'total': 15800.0, 'status': 'Delivered', 'date': 'Mar 3'},
    ];

    final topProducts = [
      {'name': 'Paracetamol 500mg 10x10', 'sold': 320, 'revenue': 192000.0},
      {'name': 'Amoxicillin 250mg 10x10', 'sold': 180, 'revenue': 270000.0},
      {'name': 'Vitamin C 500mg 30s',     'sold': 240, 'revenue': 768000.0},
      {'name': 'ORS Sachet Box 50s',       'sold': 400, 'revenue': 440000.0},
    ];

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          SafeArea(child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
                const SizedBox(width: 4),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Wholesale', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  Text('Bulk order management', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
                ElevatedButton.icon(
                  onPressed: () => context.push('/wholesale-pos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.accentCyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Stat cards
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6),
                  itemCount: stats.length,
                  itemBuilder: (_, i) {
                    final s = stats[i];
                    final color = s['color'] as Color;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(s['icon'] as IconData, color: color, size: 22),
                            const Spacer(),
                            Text(s['value'] as String, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
                            Text(s['label'] as String, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Recent orders
                const Text('Recent Orders', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ...recentOrders.map((o) => _orderCard(o)),
                const SizedBox(height: 20),

                // Top products
                const Text('Top Products This Month', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: topProducts.asMap().entries.map((e) => Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                    color: EnhancedTheme.accentCyan.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(child: Text('${e.key + 1}',
                                    style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w700))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.value['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${e.value['sold']} units sold', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                              ])),
                              Text('₹${((e.value['revenue'] as double) / 1000).toStringAsFixed(0)}K',
                                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          if (e.key < topProducts.length - 1)
                            Divider(height: 1, color: Colors.white.withOpacity(0.07)),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            )),
          ])),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    Color statusColor;
    switch (o['status']) {
      case 'Delivered':  statusColor = EnhancedTheme.successGreen; break;
      case 'Processing': statusColor = EnhancedTheme.accentCyan;   break;
      default:           statusColor = EnhancedTheme.warningAmber;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(o['id'] as String, style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(o['date'] as String, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              Text(o['customer'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${o['items']} items', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${(o['total'] as double).toStringAsFixed(0)}',
                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(o['status'] as String, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
