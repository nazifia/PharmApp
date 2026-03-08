import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_api_client.dart';

class WholesaleDashboard extends ConsumerWidget {
  const WholesaleDashboard({super.key});

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(0)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesTodayAsync  = ref.watch(salesReportProvider('today'));
    final salesMonthAsync  = ref.watch(salesReportProvider('month'));
    final customerAsync    = ref.watch(customerReportProvider);

    // Derive stat values
    final revenue     = salesTodayAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final orderCount  = salesTodayAsync.whenOrNull(data: (d) => d.topItems.fold(0, (s, i) => s + i.qty)) ?? 0;
    final wsCustomers = customerAsync.whenOrNull(data: (d) => d.wholesale) ?? 0;
    final isLoading   = salesTodayAsync.isLoading || customerAsync.isLoading;

    final stats = [
      {'label': 'Today\'s Revenue', 'value': isLoading ? '—' : _fmt(revenue),        'icon': Icons.trending_up_rounded,    'color': EnhancedTheme.successGreen},
      {'label': 'Units Sold',       'value': isLoading ? '—' : '$orderCount',         'icon': Icons.shopping_cart_rounded,  'color': EnhancedTheme.primaryTeal},
      {'label': 'WS Customers',     'value': isLoading ? '—' : '$wsCustomers',        'icon': Icons.store_rounded,          'color': EnhancedTheme.accentCyan},
      {'label': 'Outstanding',      'value': customerAsync.whenOrNull(data: (d) => _fmt(d.totalDebt)) ?? '—',
          'icon': Icons.money_off_rounded, 'color': EnhancedTheme.warningAmber},
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
                    final s     = stats[i];
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
                            isLoading && s['value'] == '—'
                                ? SizedBox(height: 22, child: LinearProgressIndicator(color: color, backgroundColor: color.withOpacity(0.1)))
                                : Text(s['value'] as String, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
                            Text(s['label'] as String, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Top Wholesale Customers
                const Text('Top Customers', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                customerAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: EnhancedTheme.accentCyan),
                  )),
                  error: (e, _) => _errorCard('Failed to load customer data'),
                  data: (report) => report.topCustomers.isEmpty
                      ? _emptyCard('No customer data yet')
                      : Column(children: report.topCustomers.take(5).map((c) => _customerCard(c)).toList()),
                ),
                const SizedBox(height: 20),

                // Top Products This Month
                const Text('Top Products This Month', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                salesMonthAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal),
                  )),
                  error: (e, _) => _errorCard('Failed to load products data'),
                  data: (report) => report.topItems.isEmpty
                      ? _emptyCard('No sales data this month')
                      : ClipRRect(
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
                                children: report.topItems.take(5).toList().asMap().entries.map((e) =>
                                  Column(children: [
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
                                          Text(e.value.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text('${e.value.qty} units sold', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                        ])),
                                        Text(_fmt(e.value.revenue),
                                            style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                                      ]),
                                    ),
                                    if (e.key < report.topItems.length - 1 && e.key < 4)
                                      Divider(height: 1, color: Colors.white.withOpacity(0.07)),
                                  ])
                                ).toList(),
                              ),
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

  Widget _customerCard(TopCustomer c) {
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
              Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${c.purchases} purchases', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(c.spent), style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w700)),
              if (c.debt > 0)
                Text('Owes ${_fmt(c.debt)}',
                    style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _errorCard(String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnhancedTheme.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EnhancedTheme.errorRed.withOpacity(0.2)),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 13)),
    ),
  );

  Widget _emptyCard(String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13))),
    ),
  );
}
