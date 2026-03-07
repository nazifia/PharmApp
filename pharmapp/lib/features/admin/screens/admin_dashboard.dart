import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    final kpis = [
      {'label': 'Today\'s Revenue', 'value': '₹1,24,500', 'sub': '+12% vs yesterday',  'color': EnhancedTheme.successGreen, 'icon': Icons.trending_up_rounded},
      {'label': 'Total Sales',      'value': '248',        'sub': 'Transactions today',  'color': EnhancedTheme.primaryTeal,  'icon': Icons.receipt_long_rounded},
      {'label': 'Low Stock Items',  'value': '7',          'sub': 'Need reorder',         'color': EnhancedTheme.warningAmber, 'icon': Icons.warning_amber_rounded},
      {'label': 'Active Staff',     'value': '12',         'sub': 'Online now',           'color': EnhancedTheme.accentCyan,   'icon': Icons.people_rounded},
      {'label': 'Outstanding Debt', 'value': '₹46,000',   'sub': 'From 8 customers',     'color': EnhancedTheme.errorRed,     'icon': Icons.money_off_rounded},
      {'label': 'Inventory Value',  'value': '₹8.4L',     'sub': 'Across 312 SKUs',      'color': EnhancedTheme.accentPurple, 'icon': Icons.inventory_2_rounded},
    ];

    final quickActions = [
      {'label': 'POS',            'icon': Icons.point_of_sale_rounded,    'route': '/dashboard/pos'},
      {'label': 'Inventory',      'icon': Icons.inventory_2_rounded,       'route': '/dashboard/inventory'},
      {'label': 'Customers',      'icon': Icons.people_rounded,            'route': '/dashboard/customers'},
      {'label': 'Reports',        'icon': Icons.bar_chart_rounded,         'route': '/dashboard/reports/sales'},
      {'label': 'Wholesale',      'icon': Icons.store_rounded,             'route': '/wholesale-dashboard'},
      {'label': 'Settings',       'icon': Icons.settings_rounded,          'route': '/dashboard/settings'},
    ];

    final recentActivity = [
      {'time': '2 min ago',  'action': 'Sale completed',       'detail': 'Invoice #1048 · ₹2,450',       'icon': Icons.check_circle_rounded,   'color': EnhancedTheme.successGreen},
      {'time': '8 min ago',  'action': 'Low stock alert',      'detail': 'Paracetamol 500mg · 5 left',  'icon': Icons.warning_amber_rounded,  'color': EnhancedTheme.warningAmber},
      {'time': '15 min ago', 'action': 'Staff login',          'detail': 'Emeka Nwosu · Cashier',        'icon': Icons.login_rounded,           'color': EnhancedTheme.accentCyan},
      {'time': '42 min ago', 'action': 'Payment received',     'detail': 'City Pharmacy · ₹18,000',      'icon': Icons.payments_rounded,        'color': EnhancedTheme.primaryTeal},
      {'time': '1 hr ago',   'action': 'Item expiry warning',  'detail': 'Tetracycline 250mg · Dec 2025','icon': Icons.event_busy_rounded,      'color': EnhancedTheme.errorRed},
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
                  Text('Admin Dashboard', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
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
                    Text(user?.role ?? 'Admin', style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 12, fontWeight: FontWeight.w700)),
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
                    final k = kpis[i];
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
                            Text(k['value'] as String, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(k['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(k['sub'] as String, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Quick actions
                const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                              Text(a['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Recent activity
                const Text('Recent Activity', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                        children: recentActivity.asMap().entries.map((e) => Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                    color: (e.value['color'] as Color).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(e.value['icon'] as IconData, color: e.value['color'] as Color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.value['action'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(e.value['detail'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                              ])),
                              Text(e.value['time'] as String, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
                            ]),
                          ),
                          if (e.key < recentActivity.length - 1)
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
}
