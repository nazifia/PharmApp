import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  String _period = 'Today';
  final _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  final _dailySales = [
    {'label': 'Mon', 'retail': 18500.0, 'wholesale': 45000.0},
    {'label': 'Tue', 'retail': 22000.0, 'wholesale': 38000.0},
    {'label': 'Wed', 'retail': 15000.0, 'wholesale': 62000.0},
    {'label': 'Thu', 'retail': 28000.0, 'wholesale': 55000.0},
    {'label': 'Fri', 'retail': 32000.0, 'wholesale': 71000.0},
    {'label': 'Sat', 'retail': 41000.0, 'wholesale': 28000.0},
    {'label': 'Sun', 'retail': 12000.0, 'wholesale': 15000.0},
  ];

  final _topItems = [
    {'name': 'Paracetamol 500mg',   'qty': 142, 'revenue': 10650.0},
    {'name': 'Vitamin C 500mg',      'qty': 87,  'revenue': 39150.0},
    {'name': 'Amoxicillin 250mg',   'qty': 63,  'revenue': 11340.0},
    {'name': 'ORS Sachet',           'qty': 210, 'revenue': 5250.0},
    {'name': 'Ibuprofen 400mg',      'qty': 95,  'revenue': 6175.0},
  ];

  double get _totalRetail    => _dailySales.fold(0, (s, d) => s + (d['retail'] as double));
  double get _totalWholesale => _dailySales.fold(0, (s, d) => s + (d['wholesale'] as double));
  double get _grandTotal     => _totalRetail + _totalWholesale;

  @override
  Widget build(BuildContext context) {
    final maxVal = _dailySales.map((d) => (d['retail'] as double) + (d['wholesale'] as double)).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          SafeArea(child: Column(children: [
            _header(context),
            _periodSelector(),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Summary cards
                Row(children: [
                  Expanded(child: _summaryCard('Total Revenue', '₹${(_grandTotal / 1000).toStringAsFixed(1)}K', EnhancedTheme.primaryTeal, Icons.trending_up_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _summaryCard('Retail', '₹${(_totalRetail / 1000).toStringAsFixed(1)}K', EnhancedTheme.accentCyan, Icons.storefront_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _summaryCard('Wholesale', '₹${(_totalWholesale / 1000).toStringAsFixed(1)}K', EnhancedTheme.accentPurple, Icons.store_rounded)),
                ]),
                const SizedBox(height: 20),

                // Bar chart
                const Text('Daily Sales (₹)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                      child: Column(children: [
                        SizedBox(
                          height: 140,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: _dailySales.map((d) {
                              final retail    = d['retail']    as double;
                              final wholesale = d['wholesale'] as double;
                              final total     = retail + wholesale;
                              final barH      = (total / maxVal) * 120;
                              final rH        = (retail / total) * barH;
                              final wH        = wholesale / total * barH;
                              return Expanded(child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Text('${(total / 1000).toStringAsFixed(0)}K',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8)),
                                  const SizedBox(height: 2),
                                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    Container(height: rH, decoration: BoxDecoration(
                                        color: EnhancedTheme.accentCyan,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                                    Container(height: wH, color: EnhancedTheme.accentPurple),
                                  ]),
                                ]),
                              ));
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: _dailySales.map((d) => Expanded(
                          child: Text(d['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10)),
                        )).toList()),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _legend(EnhancedTheme.accentCyan, 'Retail'),
                          const SizedBox(width: 20),
                          _legend(EnhancedTheme.accentPurple, 'Wholesale'),
                        ]),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Top items
                const Text('Top Selling Items', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                        children: _topItems.asMap().entries.map((e) => Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                    color: EnhancedTheme.primaryTeal.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(child: Text('${e.key + 1}',
                                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w700))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(e.value['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('₹${(e.value['revenue'] as double).toStringAsFixed(0)}',
                                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                                Text('${e.value['qty']} units', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                              ]),
                            ]),
                          ),
                          if (e.key < _topItems.length - 1)
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

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
      const SizedBox(width: 4),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sales Report', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        Text('Revenue & transaction analytics', style: TextStyle(color: Colors.white38, fontSize: 11)),
      ])),
      IconButton(
        icon: const Icon(Icons.download_rounded, color: Colors.white70),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export – coming soon'))),
      ),
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
            color: active ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(p, textAlign: TextAlign.center,
              style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ));
    }).toList()),
  );

  Widget _summaryCard(String label, String value, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
  ]);
}
