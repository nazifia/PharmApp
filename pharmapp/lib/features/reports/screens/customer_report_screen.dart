import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class CustomerReportScreen extends ConsumerWidget {
  const CustomerReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = [
      {'label': 'Total Customers', 'value': '284',     'color': EnhancedTheme.primaryTeal,  'icon': Icons.people_rounded},
      {'label': 'New This Month',  'value': '18',      'color': EnhancedTheme.successGreen, 'icon': Icons.person_add_rounded},
      {'label': 'Wholesale',       'value': '42',      'color': EnhancedTheme.accentCyan,   'icon': Icons.store_rounded},
      {'label': 'Outstanding',     'value': '₹46K',   'color': EnhancedTheme.errorRed,     'icon': Icons.money_off_rounded},
      {'label': 'Wallet Balance',  'value': '₹28K',   'color': EnhancedTheme.successGreen, 'icon': Icons.account_balance_wallet_rounded},
      {'label': 'Loyalty Points',  'value': '12.4K',  'color': EnhancedTheme.accentPurple, 'icon': Icons.star_rounded},
    ];

    final topCustomers = [
      {'name': 'City Pharmacy',     'type': 'Wholesale', 'spent': 284500.0, 'visits': 87},
      {'name': 'Sunrise Medical',   'type': 'Wholesale', 'spent': 195000.0, 'visits': 53},
      {'name': 'Fatima Aliyu',      'type': 'Retail',    'spent': 28450.0,  'visits': 38},
      {'name': 'Green Cross Clinic','type': 'Wholesale', 'spent': 165000.0, 'visits': 41},
      {'name': 'Adaeze Okafor',     'type': 'Retail',    'spent': 22300.0,  'visits': 24},
    ];

    final debtors = [
      {'name': 'Medicare Hub',   'debt': 22000.0, 'overdue': true},
      {'name': 'City Pharmacy',  'debt': 15000.0, 'overdue': false},
      {'name': 'Sunrise Medical','debt': 8500.0,  'overdue': true},
      {'name': 'Chidi Eze',      'debt': 500.0,   'overdue': false},
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
                  Text('Customer Report', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Customer analytics & debt tracking', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
              ]),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Metrics
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3),
                  itemCount: metrics.length,
                  itemBuilder: (_, i) {
                    final m = metrics[i];
                    final color = m['color'] as Color;
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
                            Icon(m['icon'] as IconData, color: color, size: 18),
                            const SizedBox(height: 4),
                            Text(m['value'] as String, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(m['label'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9), textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Segmentation donut placeholder
                const Text('Customer Segments', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                      child: Row(children: [
                        Expanded(child: _segBar('Retail',    242, 284, EnhancedTheme.primaryTeal)),
                        const SizedBox(width: 10),
                        Expanded(child: _segBar('Wholesale', 42,  284, EnhancedTheme.accentCyan)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Top customers
                const Text('Top Customers by Spend', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                        children: topCustomers.asMap().entries.map((e) => Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: (e.value['type'] == 'Wholesale'
                                    ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal).withOpacity(0.15),
                                child: Text('${e.key + 1}', style: TextStyle(
                                    color: e.value['type'] == 'Wholesale' ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal,
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.value['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('${e.value['type']} · ${e.value['visits']} visits', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                              ])),
                              Text('₹${((e.value['spent'] as double) / 1000).toStringAsFixed(1)}K',
                                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          if (e.key < topCustomers.length - 1)
                            Divider(height: 1, color: Colors.white.withOpacity(0.07)),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Debtors
                Row(children: [
                  const Expanded(child: Text('Outstanding Debts', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: EnhancedTheme.errorRed.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('₹46K total', style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                ...debtors.map((d) => _debtRow(d)),
                const SizedBox(height: 24),
              ]),
            )),
          ])),
        ],
      ),
    );
  }

  Widget _segBar(String label, int count, int total, Color color) {
    final pct = count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
        Text('$count (${(pct * 100).round()}%)', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ),
    ]);
  }

  Widget _debtRow(Map<String, dynamic> d) {
    final overdue = d['overdue'] as bool;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withOpacity(overdue ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnhancedTheme.errorRed.withOpacity(overdue ? 0.3 : 0.15)),
          ),
          child: Row(children: [
            Icon(Icons.money_off_rounded, color: EnhancedTheme.errorRed.withOpacity(overdue ? 1 : 0.5), size: 18),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              if (overdue) const Text('Overdue', style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 10, fontWeight: FontWeight.w700)),
            ])),
            Text('₹${(d['debt'] as double).toStringAsFixed(0)}',
                style: TextStyle(color: EnhancedTheme.errorRed.withOpacity(overdue ? 1 : 0.7), fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
