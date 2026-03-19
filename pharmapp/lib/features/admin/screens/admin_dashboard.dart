import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _fmt(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  void _logout() {
    ref.read(authServiceProvider).logout();
    context.go('/login');
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AdminMoreSheet(
        onNavigate: (route) { Navigator.pop(context); context.go(route); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user          = ref.watch(currentUserProvider);
    final salesToday    = ref.watch(salesReportProvider('today'));
    final inventoryRpt  = ref.watch(inventoryReportProvider);
    final customerRpt   = ref.watch(customerReportProvider);

    final revenue      = salesToday.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final lowStock     = inventoryRpt.whenOrNull(data: (d) => d.lowStockCount) ?? 0;
    final customers    = customerRpt.whenOrNull(data: (d) => d.total) ?? 0;
    final debt         = customerRpt.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final stockValue   = inventoryRpt.whenOrNull(data: (d) => d.stockValue) ?? 0.0;
    final topItemCount = salesToday.whenOrNull(data: (d) => d.topItems.length) ?? 0;
    final isLoading    = salesToday.isLoading || inventoryRpt.isLoading || customerRpt.isLoading;

    String kpiVal(String val) => isLoading ? '—' : val;

    final kpis = [
      {'label': 'Today\'s Revenue', 'value': kpiVal(_fmt(revenue)),   'sub': 'Retail + Wholesale',  'color': EnhancedTheme.successGreen, 'icon': Icons.trending_up_rounded},
      {'label': 'Top Items Today',  'value': kpiVal('$topItemCount'), 'sub': 'Distinct items sold',  'color': EnhancedTheme.primaryTeal,  'icon': Icons.receipt_long_rounded},
      {'label': 'Low Stock Items',  'value': kpiVal('$lowStock'),     'sub': 'Need reorder',         'color': EnhancedTheme.warningAmber, 'icon': Icons.warning_amber_rounded},
      {'label': 'Customers',        'value': kpiVal('$customers'),    'sub': 'Total registered',     'color': EnhancedTheme.accentCyan,   'icon': Icons.people_rounded},
      {'label': 'Outstanding Debt', 'value': kpiVal(_fmt(debt)),      'sub': 'Total customer debt',  'color': EnhancedTheme.errorRed,     'icon': Icons.money_off_rounded},
      {'label': 'Inventory Value',  'value': kpiVal(_fmt(stockValue)), 'sub': inventoryRpt.whenOrNull(data: (d) => '${d.totalItems} items') ?? 'Across all items', 'color': EnhancedTheme.accentPurple, 'icon': Icons.inventory_2_rounded},
    ];

    final quickActions = [
      {'label': 'POS',       'icon': Icons.point_of_sale_rounded,  'color': EnhancedTheme.primaryTeal,  'route': '/dashboard/pos'},
      {'label': 'Inventory', 'icon': Icons.inventory_2_rounded,     'color': EnhancedTheme.infoBlue,     'route': '/dashboard/inventory'},
      {'label': 'Customers', 'icon': Icons.people_rounded,          'color': EnhancedTheme.accentPurple, 'route': '/dashboard/customers'},
      {'label': 'Reports',   'icon': Icons.bar_chart_rounded,       'color': EnhancedTheme.successGreen, 'route': '/dashboard/reports'},
      {'label': 'Wholesale', 'icon': Icons.store_rounded,           'color': EnhancedTheme.accentCyan,   'route': '/wholesale-dashboard'},
      {'label': 'More',      'icon': Icons.more_horiz_rounded,      'color': Colors.white38,             'route': ''},
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(child: Column(children: [
            // ── Header ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Icon(Icons.menu_rounded, color: context.iconOnBg, size: 20),
                  ),
                ),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Admin Dashboard',
                      style: TextStyle(color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Welcome back, ${user?.role ?? 'Admin'}',
                      style: TextStyle(color: context.hintColor, fontSize: 12)),
                ])),
                // Profile dropdown menu
                _buildProfileMenu(user?.role ?? 'Admin'),
              ]),
            ),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── KPI grid ─────────────────────────────────────────────────
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
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(k['icon'] as IconData, color: color, size: 20),
                            const Spacer(),
                            isLoading
                                ? SizedBox(height: 18, child: LinearProgressIndicator(
                                    color: color, backgroundColor: color.withValues(alpha: 0.1)))
                                : Text(k['value'] as String,
                                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(k['label'] as String,
                                style: TextStyle(color: context.labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(k['sub'] as String,
                                style: TextStyle(color: context.hintColor, fontSize: 10)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Quick actions ─────────────────────────────────────────────
                Text('Quick Actions',
                    style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3),
                  itemCount: quickActions.length,
                  itemBuilder: (_, i) {
                    final a     = quickActions[i];
                    final color = a['color'] as Color;
                    return GestureDetector(
                      onTap: () {
                        final route = a['route'] as String;
                        if (route.isEmpty) {
                          _showMoreSheet();
                        } else {
                          context.push(route);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: color.withValues(alpha: 0.2)),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(a['icon'] as IconData, color: color, size: 26),
                              const SizedBox(height: 6),
                              Text(a['label'] as String,
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Top Items Today ───────────────────────────────────────────
                Text('Top Items Today',
                    style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
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
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.medication_rounded,
                                          color: EnhancedTheme.primaryTeal, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(e.value.name,
                                          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('${e.value.qty} units sold',
                                          style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                                    ])),
                                    Text(_fmt(e.value.revenue),
                                        style: const TextStyle(color: EnhancedTheme.successGreen,
                                            fontSize: 14, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                if (e.key < report.topItems.length - 1 && e.key < 4)
                                  Divider(height: 1, color: context.dividerColor),
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

  // ── Profile dropdown ──────────────────────────────────────────────────────

  Widget _buildProfileMenu(String role) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E293B),
      onSelected: (val) {
        switch (val) {
          case 'settings':   context.go('/admin-dashboard/settings'); break;
          case 'retail':     context.go('/dashboard');                break;
          case 'wholesale':  context.go('/wholesale-dashboard');      break;
          case 'reports':    context.go('/dashboard/reports');        break;
          case 'more':       _showMoreSheet();                        break;
          case 'logout':     _logout();                               break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.2),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: EnhancedTheme.errorRed, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const Text('Admin Dashboard', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ])),
        const PopupMenuDivider(),
        _menuItem('settings',  Icons.settings_outlined,       'Settings'),
        _menuItem('reports',   Icons.bar_chart_outlined,      'Reports'),
        _menuItem('retail',    Icons.storefront_outlined,      'Retail Dashboard'),
        _menuItem('wholesale', Icons.store_outlined,           'Wholesale Dashboard'),
        _menuItem('more',      Icons.more_horiz_rounded,       'More Features'),
        const PopupMenuDivider(),
        _menuItem('logout',    Icons.logout_rounded,           'Sign Out', color: EnhancedTheme.errorRed),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: EnhancedTheme.errorRed, width: 2),
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.15),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: EnhancedTheme.errorRed, size: 20),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.white70;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: c, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c, fontSize: 13)),
      ]),
    );
  }

  Widget _infoTile(String msg, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
      ),
    );
  }
}

// ── More Features Bottom Sheet ────────────────────────────────────────────────

class _AdminMoreSheet extends StatelessWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _AdminMoreSheet({required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('More Features', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),

            _sectionLabel(context, 'Reports'),
            const SizedBox(height: 8),
            Row(children: [
              _card(context, Icons.show_chart,           'Sales',      EnhancedTheme.successGreen, '/dashboard/reports/sales'),
              const SizedBox(width: 10),
              _card(context, Icons.inventory_2_outlined,  'Inventory', EnhancedTheme.infoBlue,    '/dashboard/reports/inventory'),
              const SizedBox(width: 10),
              _card(context, Icons.people_outline,        'Customers', EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
              const SizedBox(width: 10),
              _card(context, Icons.trending_up,           'Profit',    EnhancedTheme.warningAmber, '/dashboard/reports/profit'),
            ]),
            const SizedBox(height: 20),

            _sectionLabel(context, 'Navigation'),
            const SizedBox(height: 8),
            Row(children: [
              _card(context, Icons.storefront_outlined,             'Retail',    EnhancedTheme.primaryTeal,  '/dashboard'),
              const SizedBox(width: 10),
              _card(context, Icons.store_outlined,                  'Wholesale', EnhancedTheme.accentCyan,   '/wholesale-dashboard'),
              const SizedBox(width: 10),
              _card(context, Icons.point_of_sale_outlined,          'POS',       EnhancedTheme.successGreen, '/dashboard/pos'),
              const SizedBox(width: 10),
              _card(context, Icons.settings_outlined,               'Settings',  context.subLabelColor,      '/admin-dashboard/settings'),
            ]),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 11,
        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
  );

  Widget _card(BuildContext context, IconData icon, String label, Color color, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onNavigate(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
