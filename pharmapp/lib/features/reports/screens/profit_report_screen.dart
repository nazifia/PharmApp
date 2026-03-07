import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  String _period = 'This Month';
  final _periods = ['This Week', 'This Month', 'This Quarter', 'This Year'];

  final _monthlyData = [
    {'month': 'Sep', 'revenue': 180000.0, 'cost': 120000.0},
    {'month': 'Oct', 'revenue': 210000.0, 'cost': 135000.0},
    {'month': 'Nov', 'revenue': 195000.0, 'cost': 128000.0},
    {'month': 'Dec', 'revenue': 260000.0, 'cost': 165000.0},
    {'month': 'Jan', 'revenue': 228000.0, 'cost': 148000.0},
    {'month': 'Feb', 'revenue': 245000.0, 'cost': 155000.0},
    {'month': 'Mar', 'revenue': 124500.0, 'cost': 78000.0},
  ];

  final _marginByCategory = [
    {'cat': 'Analgesics',   'margin': 0.42},
    {'cat': 'Antibiotics',  'margin': 0.35},
    {'cat': 'Vitamins',     'margin': 0.55},
    {'cat': 'Antidiabetics','margin': 0.28},
    {'cat': 'Cardiovasc.',  'margin': 0.38},
  ];

  double get _totalRevenue => _monthlyData.fold(0, (s, d) => s + (d['revenue'] as double));
  double get _totalCost    => _monthlyData.fold(0, (s, d) => s + (d['cost'] as double));
  double get _totalProfit  => _totalRevenue - _totalCost;
  double get _margin       => _totalProfit / _totalRevenue;

  @override
  Widget build(BuildContext context) {
    final maxRev = _monthlyData.map((d) => d['revenue'] as double).reduce((a, b) => a > b ? a : b);

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
                  Text('Profit Report', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Revenue, cost & margin analysis', style: TextStyle(color: Colors.white38, fontSize: 11)),
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
                      color: active ? EnhancedTheme.successGreen : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(p, textAlign: TextAlign.center,
                        style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ));
              }).toList()),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // P&L cards
                Row(children: [
                  Expanded(child: _plCard('Revenue', '₹${(_totalRevenue / 100000).toStringAsFixed(1)}L', EnhancedTheme.primaryTeal, Icons.trending_up_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _plCard('Cost',    '₹${(_totalCost / 100000).toStringAsFixed(1)}L',    EnhancedTheme.errorRed,     Icons.trending_down_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _plCard('Profit',  '₹${(_totalProfit / 100000).toStringAsFixed(1)}L',  EnhancedTheme.successGreen, Icons.savings_rounded)),
                ]),
                const SizedBox(height: 10),
                // Margin card
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EnhancedTheme.successGreen.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.percent_rounded, color: EnhancedTheme.successGreen, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Net Profit Margin', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('Based on ${_monthlyData.length} months of data', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                        ])),
                        Text('${(_margin * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Monthly revenue vs cost chart
                const Text('Monthly Revenue vs Cost', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                            children: _monthlyData.map((d) {
                              final rev    = d['revenue'] as double;
                              final cost   = d['cost']    as double;
                              final revH   = (rev / maxRev) * 120;
                              final costH  = (cost / maxRev) * 120;
                              final profit = rev - cost;

                              return Expanded(child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Text('${(profit / 1000).toStringAsFixed(0)}K',
                                      style: TextStyle(color: EnhancedTheme.successGreen.withOpacity(0.7), fontSize: 7)),
                                  const SizedBox(height: 2),
                                  Stack(alignment: Alignment.bottomCenter, children: [
                                    Container(
                                      height: revH,
                                      decoration: BoxDecoration(
                                        color: EnhancedTheme.primaryTeal.withOpacity(0.3),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                    Container(
                                      height: costH,
                                      decoration: BoxDecoration(
                                        color: EnhancedTheme.errorRed.withOpacity(0.5),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                      ),
                                    ),
                                  ]),
                                ]),
                              ));
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: _monthlyData.map((d) => Expanded(
                          child: Text(d['month'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9)),
                        )).toList()),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _legend(EnhancedTheme.primaryTeal.withOpacity(0.6), 'Revenue'),
                          const SizedBox(width: 16),
                          _legend(EnhancedTheme.errorRed.withOpacity(0.7), 'Cost'),
                          const SizedBox(width: 16),
                          _legend(EnhancedTheme.successGreen, 'Profit'),
                        ]),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Margin by category
                const Text('Margin by Category', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                        children: _marginByCategory.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            SizedBox(width: 90, child: Text(c['cat'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: c['margin'] as double,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    (c['margin'] as double) > 0.4 ? EnhancedTheme.successGreen : EnhancedTheme.primaryTeal),
                                minHeight: 8,
                              ),
                            )),
                            const SizedBox(width: 10),
                            Text('${((c['margin'] as double) * 100).round()}%',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                        )).toList(),
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

  Widget _plCard(String label, String value, Color color, IconData icon) => ClipRRect(
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
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
        ]),
      ),
    ),
  );

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
  ]);
}
