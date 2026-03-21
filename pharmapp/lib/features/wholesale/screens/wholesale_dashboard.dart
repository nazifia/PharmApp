import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_api_client.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

class WholesaleDashboard extends ConsumerStatefulWidget {
  const WholesaleDashboard({super.key});

  @override
  ConsumerState<WholesaleDashboard> createState() => _WholesaleDashboardState();
}

class _WholesaleDashboardState extends ConsumerState<WholesaleDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(0)}K';
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
      builder: (_) => _WholesaleMoreSheet(
        onNavigate: (route) { Navigator.pop(context); context.go(route); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  Widget _buildProfileMenu(String? role) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        switch (val) {
          case 'settings':   context.push('/dashboard/settings'); break;
          case 'reports':    context.push('/dashboard/reports'); break;
          case 'retail':     context.go('/dashboard'); break;
          case 'admin':      context.go('/admin-dashboard'); break;
          case 'logout':     _logout(); break;
        }
      },
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role ?? 'Wholesale', style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 13)),
            const Text('Wholesale dashboard', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        const PopupMenuDivider(),
        _menuItem('settings', Icons.settings_outlined, 'Settings'),
        _menuItem('reports',  Icons.bar_chart_rounded,  'Reports'),
        _menuItem('retail',   Icons.storefront_rounded,  'Retail Dashboard'),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18, color: EnhancedTheme.errorRed),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: EnhancedTheme.errorRed, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
        child: const Icon(Icons.store_rounded, size: 18, color: EnhancedTheme.accentCyan),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final user           = ref.watch(currentUserProvider);
    final salesTodayAsync = ref.watch(salesReportProvider('today'));
    final salesMonthAsync = ref.watch(salesReportProvider('month'));
    final customerAsync   = ref.watch(customerReportProvider);

    final revenue    = salesTodayAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final orderCount = salesTodayAsync.whenOrNull(data: (d) => d.topItems.fold<int>(0, (s, i) => s + i.qty)) ?? 0;
    final wsCustomers = customerAsync.whenOrNull(data: (d) => d.wholesale) ?? 0;
    final isLoading  = salesTodayAsync.isLoading || customerAsync.isLoading;

    final stats = [
      {'label': 'Today\'s Revenue', 'value': isLoading ? '—' : _fmt(revenue),   'icon': Icons.trending_up_rounded,   'color': EnhancedTheme.successGreen},
      {'label': 'Units Sold',       'value': isLoading ? '—' : '$orderCount',    'icon': Icons.shopping_cart_rounded,  'color': EnhancedTheme.primaryTeal},
      {'label': 'WS Customers',     'value': isLoading ? '—' : '$wsCustomers',   'icon': Icons.store_rounded,          'color': EnhancedTheme.accentCyan},
      {'label': 'Outstanding',      'value': customerAsync.whenOrNull(data: (d) => _fmt(d.totalDebt)) ?? '—',
          'icon': Icons.money_off_rounded, 'color': EnhancedTheme.warningAmber},
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                color: context.iconOnBg,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Wholesale',
                    style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Bulk order management',
                    style: TextStyle(color: context.hintColor, fontSize: 11)),
              ])),
              ElevatedButton.icon(
                onPressed: () => context.push('/dashboard/wholesale-pos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.accentCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              _buildProfileMenu(user?.role),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Stat cards ──────────────────────────────────────────────────
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12,
                    crossAxisSpacing: 12, childAspectRatio: 1.6),
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
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(s['icon'] as IconData, color: color, size: 22),
                          const Spacer(),
                          isLoading && s['value'] == '—'
                              ? SizedBox(height: 22,
                                  child: LinearProgressIndicator(
                                      color: color,
                                      backgroundColor: color.withValues(alpha: 0.1)))
                              : Text(s['value'] as String,
                                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
                          Text(s['label'] as String,
                              style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Top Wholesale Customers ──────────────────────────────────────
              Text('Top Customers',
                  style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              customerAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: EnhancedTheme.accentCyan),
                )),
                error: (e, _) => _errorCard(context, 'Failed to load customer data'),
                data: (report) => report.topCustomers.isEmpty
                    ? _emptyCard(context, 'No customer data yet')
                    : Column(children: report.topCustomers.take(5).map((c) => _customerCard(context, c)).toList()),
              ),
              const SizedBox(height: 20),

              // ── Top Products This Month ──────────────────────────────────────
              Text('Top Products This Month',
                  style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              salesMonthAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal),
                )),
                error: (e, _) => _errorCard(context, 'Failed to load products data'),
                data: (report) => report.topItems.isEmpty
                    ? _emptyCard(context, 'No sales data this month')
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
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
                                            color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8)),
                                        child: Center(child: Text('${e.key + 1}',
                                            style: const TextStyle(color: EnhancedTheme.accentCyan,
                                                fontSize: 12, fontWeight: FontWeight.w700))),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(e.value.name,
                                            style: TextStyle(color: context.labelColor,
                                                fontSize: 13, fontWeight: FontWeight.w500),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('${e.value.qty} units sold',
                                            style: TextStyle(color: context.hintColor, fontSize: 11)),
                                      ])),
                                      Text(_fmt(e.value.revenue),
                                          style: const TextStyle(color: EnhancedTheme.primaryTeal,
                                              fontSize: 13, fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                  if (e.key < report.topItems.length - 1 && e.key < 4)
                                    Divider(height: 1, color: context.dividerColor),
                                ])
                              ).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // ── More button ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showMoreSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.labelColor,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(Icons.apps_rounded, color: context.subLabelColor),
                  label: Text('More Features', style: TextStyle(color: context.subLabelColor)),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _customerCard(BuildContext context, TopCustomer c) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name,
                style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt(c.spent),
                style: const TextStyle(color: EnhancedTheme.primaryTeal,
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    ),
  );

  Widget _errorCard(BuildContext context, String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
      ),
      child: Text(msg, style: TextStyle(color: context.subLabelColor, fontSize: 13)),
    ),
  );

  Widget _emptyCard(BuildContext context, String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Center(child: Text(msg,
          style: TextStyle(color: context.hintColor, fontSize: 13))),
    ),
  );
}

// ── Wholesale More Sheet ───────────────────────────────────────────────────────

class _WholesaleMoreSheet extends StatelessWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _WholesaleMoreSheet({required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),

            Text('Reports', style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              _sheetTile(context, Icons.bar_chart_rounded,       'Sales',     EnhancedTheme.primaryTeal,  '/dashboard/reports/sales'),
              _sheetTile(context, Icons.inventory_2_rounded,     'Inventory', EnhancedTheme.accentCyan,   '/dashboard/reports/inventory'),
              _sheetTile(context, Icons.people_rounded,          'Customers', EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
              _sheetTile(context, Icons.savings_rounded,         'Profit',    EnhancedTheme.successGreen, '/dashboard/reports/profit'),
            ]),
            const SizedBox(height: 20),

            Text('Navigate', style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              _sheetTile(context, Icons.storefront_rounded,      'Retail',      EnhancedTheme.primaryTeal,  '/dashboard'),
              _sheetTile(context, Icons.point_of_sale_rounded,   'Retail POS',  EnhancedTheme.accentCyan,   '/dashboard/pos'),
              _sheetTile(context, Icons.settings_rounded,        'Settings',    EnhancedTheme.accentPurple, '/dashboard/settings'),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                  foregroundColor: EnhancedTheme.errorRed,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sheetTile(BuildContext context, IconData icon, String label, Color color, String route) =>
      Expanded(child: GestureDetector(
        onTap: () => onNavigate(route),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(color: context.subLabelColor, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
      ));
}
