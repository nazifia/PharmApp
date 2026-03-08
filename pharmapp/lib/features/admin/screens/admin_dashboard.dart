import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  String _fmt(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(currentUserProvider);
    final salesToday    = ref.watch(salesReportProvider('today'));
    final inventoryRpt  = ref.watch(inventoryReportProvider);
    final customerRpt   = ref.watch(customerReportProvider);

    final revenue      = salesToday.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final lowStock     = inventoryRpt.whenOrNull(data: (d) => d.lowStock) ?? 0;
    final customers    = customerRpt.whenOrNull(data: (d) => d.total) ?? 0;
    final debt         = customerRpt.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final stockValue   = inventoryRpt.whenOrNull(data: (d) => d.stockValue) ?? 0.0;
    final topItemCount = salesToday.whenOrNull(data: (d) => d.topItems.length) ?? 0;
    final isLoading    = salesToday.isLoading || inventoryRpt.isLoading || customerRpt.isLoading;

    String kpiVal(String val) => isLoading ? '—' : val;

    final kpis = [
      {'label': 'Today\'s Revenue', 'value': kpiVal(_fmt(revenue)),          'sub': 'Retail + Wholesale',       'color': EnhancedTheme.successGreen, 'icon': Icons.trending_up_rounded},
      {'label': 'Top Items Today',  'value': kpiVal('$topItemCount'),         'sub': 'Distinct items sold',      'color': EnhancedTheme.primaryTeal,  'icon': Icons.receipt_long_rounded},
      {'label': 'Low Stock Items',  'value': kpiVal('$lowStock'),             'sub': 'Need reorder',             'color': EnhancedTheme.warningAmber, 'icon': Icons.warning_amber_rounded},
      {'label': 'Customers',        'value': kpiVal('$customers'),            'sub': 'Total registered',         'color': EnhancedTheme.accentCyan,   'icon': Icons.people_rounded},
      {'label': 'Outstanding Debt', 'value': kpiVal(_fmt(debt)),              'sub': 'Total customer debt',      'color': EnhancedTheme.errorRed,     'icon': Icons.money_off_rounded},
      {'label': 'Inventory Value',  'value': kpiVal(_fmt(stockValue)),        'sub': inventoryRpt.whenOrNull(data: (d) => '${d.totalSkus} SKUs') ?? 'Across all SKUs', 'color': EnhancedTheme.accentPurple, 'icon': Icons.inventory_2_rounded},
    ];

    final quickActions = [
      {'label': 'POS',       'icon': Icons.point_of_sale_rounded,   'route': '/dashboard/pos'},
      {'label': 'Inventory', 'icon': Icons.inventory_2_rounded,      'route': '/dashboard/inventory'},
      {'label': 'Customers', 'icon': Icons.people_rounded,           'route': '/dashboard/customers'},
      {'label': 'Reports',   'icon': Icons.bar_chart_rounded,        'route': '/dashboard/reports/sales'},
      {'label': 'Wholesale', 'icon': Icons.store_rounded,            'route': '/wholesale-dashboard'},
      {'label': 'Settings',  'icon': Icons.settings_rounded,         'route': '/dashboard/settings'},
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Admin Dashboard',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Welcome back, ${user?.role ?? 'Admin'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnhancedTheme.errorRed.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: EnhancedTheme.errorRed, size: 14),
                    const SizedBox(width: 6),
                    Text(user?.role ?? 'Admin',
                        style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // KPI grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5),
                  itemCount: kpis.length,
                  itemBuilder: (_, i) {
                    final k     = kpis[i];
                    final color = k['color'] as Color;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(k['icon'] as IconData, color: color, size: 20),
                            const Spacer(),
                            isLoading
                                ? SizedBox(height: 18,
                                    child: LinearProgressIndicator(color: color, backgroundColor: color.withOpacity(0.1)))
                                : Text(k['value'] as String,
                                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(k['label'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(k['sub'] as String,
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Quick actions
                const Text('Quick Actions',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3),
                  itemCount: quickActions.length,
                  itemBuilder: (_, i) {
                    final a = quickActions[i];
                    return GestureDetector(
                      onTap: () => context.push(a['route'] as String),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(a['icon'] as IconData, color: EnhancedTheme.primaryTeal, size: 26),
                              const SizedBox(height: 6),
                              Text(a['label'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Top Items Today
                const Text('Top Items Today',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                salesToday.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal),
                  )),
                  error: (e, _) => _infoTile('Failed to load sales data', EnhancedTheme.errorRed),
                  data: (report) {
                    if (report.topItems.isEmpty) {
                      return _infoTile('No sales recorded today', Colors.white38);
                    }
                    return ClipRRect(
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                          color: EnhancedTheme.primaryTeal.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.medication_rounded, color: EnhancedTheme.primaryTeal, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(e.value.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('${e.value.qty} units sold',
                                          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                                    ])),
                                    Text(_fmt(e.value.revenue),
                                        style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 14, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                if (e.key < report.topItems.length - 1 && e.key < 4)
                                  Divider(height: 1, color: Colors.white.withOpacity(0.07)),
                              ])
                            ).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ]),
            )),
          ])),
        ],
      ),
    );
  }

  Widget _infoTile(String msg, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
      ),
    );
  }
}
