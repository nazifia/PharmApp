import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/shared/widgets/dashboard_card.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _onNavTap(int i) {
    setState(() => _selectedIndex = i);
    switch (i) {
      case 1: context.go('/dashboard/pos');        break;
      case 2: context.go('/dashboard/inventory');  break;
      case 3: context.go('/dashboard/customers');  break;
      case 4: context.go('/dashboard/reports');    break;
    }
  }

  void _logout() {
    ref.read(authServiceProvider).logout();
    context.go('/login');
  }

  void _showMoreSheet() {
    final user = ref.read(currentUserProvider);
    final isAdmin     = user?.role == 'Admin' || user?.role == 'Manager';
    final isWholesale = (user?.role.contains('Wholesale') ?? false) || (user?.isWholesaleOperator ?? false) || isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreFeaturesSheet(
        isAdmin: isAdmin,
        isWholesale: isWholesale,
        onNavigate: (route) { Navigator.pop(context); context.go(route); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(child: wide ? _wideLayout() : _narrowLayout()),
        ],
      ),
    );
  }

  Widget _wideLayout() => Row(children: [
    _buildNavRail(),
    VerticalDivider(width: 1, color: context.dividerColor),
    Expanded(child: _content()),
  ]);

  Widget _narrowLayout() => Column(children: [
    Expanded(child: _content()),
    _bottomNav(),
  ]);

  Widget _buildNavRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onNavTap,
      labelType: NavigationRailLabelType.all,
      backgroundColor: context.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      selectedIconTheme: const IconThemeData(color: Color(0xFF0D9488)),
      unselectedIconTheme: IconThemeData(color: context.subLabelColor),
      selectedLabelTextStyle: const TextStyle(color: Color(0xFF0D9488), fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: context.subLabelColor, fontSize: 11),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0D9488), size: 22),
        ),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha:0.4)),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_outlined),          selectedIcon: Icon(Icons.home),          label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('POS')),
        NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined),   selectedIcon: Icon(Icons.inventory_2),   label: Text('Stock')),
        NavigationRailDestination(icon: Icon(Icons.people_outline),          selectedIcon: Icon(Icons.people),        label: Text('Customers')),
        NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined),      selectedIcon: Icon(Icons.bar_chart),     label: Text('Reports')),
      ],
    );
  }

  Widget _bottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.95),
            border: Border(top: BorderSide(color: context.dividerColor)),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onNavTap,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: const Color(0xFF0D9488),
            unselectedItemColor: context.hintColor,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined),          activeIcon: Icon(Icons.home),          label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), activeIcon: Icon(Icons.point_of_sale), label: 'POS'),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined),   activeIcon: Icon(Icons.inventory_2),   label: 'Stock'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline),          activeIcon: Icon(Icons.people),        label: 'Customers'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),      activeIcon: Icon(Icons.bar_chart),     label: 'Reports'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() => _homeContent();

  Widget _homeContent() {
    final user       = ref.watch(currentUserProvider);
    final salesAsync = ref.watch(salesReportProvider('today'));
    final invAsync   = ref.watch(inventoryReportProvider);
    final custAsync  = ref.watch(customerReportProvider);
    final wide2      = MediaQuery.of(context).size.width > 600;
    final hour       = DateTime.now().hour;
    final greeting   = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final revenue   = salesAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final lowStock  = invAsync.whenOrNull(data: (d) => d.lowStockCount) ?? 0;
    final customers = custAsync.whenOrNull(data: (d) => d.total) ?? 0;
    final debt      = custAsync.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final loading   = salesAsync.isLoading || invAsync.isLoading || custAsync.isLoading;

    final stats = [
      DashboardCard(title: "Today's Revenue", value: loading ? '…' : _fmt(revenue), subtitle: 'Retail + Wholesale', icon: Icons.monetization_on,  color: const Color(0xFF10B981)),
      DashboardCard(title: 'Low Stock',        value: loading ? '…' : '$lowStock',   subtitle: 'Below threshold',     icon: Icons.warning_amber,    color: const Color(0xFFF59E0B)),
      DashboardCard(title: 'Customers',        value: loading ? '…' : '$customers',  subtitle: 'Total registered',    icon: Icons.people,           color: const Color(0xFF8B5CF6)),
      DashboardCard(title: 'Outstanding Debt', value: loading ? '…' : _fmt(debt),    subtitle: 'Total owed',          icon: Icons.money_off,        color: const Color(0xFFEF4444)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(children: [
            if (!wide2)
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
                  child: Icon(Icons.menu_rounded, color: context.labelColor, size: 20),
                ),
              ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting!', style: TextStyle(color: context.subLabelColor, fontSize: 13)),
              const SizedBox(height: 2),
              Text(user?.phoneNumber ?? 'User',
                  style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(color: context.hintColor, fontSize: 12)),
            ])),
            _buildProfileMenu(user?.role ?? 'U'),
          ]),
          const SizedBox(height: 24),

          // ── Quick actions ─────────────────────────────────────────────────
          Row(children: [
            _quickBtn(Icons.add_shopping_cart, 'New Sale',   const Color(0xFF0D9488), () => context.go('/dashboard/pos')),
            const SizedBox(width: 10),
            _quickBtn(Icons.inventory_2,        'Inventory',  const Color(0xFF3B82F6), () => context.go('/dashboard/inventory')),
            const SizedBox(width: 10),
            _quickBtn(Icons.people,             'Customers',  const Color(0xFF8B5CF6), () => context.go('/dashboard/customers')),
            const SizedBox(width: 10),
            _quickBtn(Icons.more_horiz_rounded,  'More',       Colors.white38,          _showMoreSheet),
          ]),
          const SizedBox(height: 24),

          // ── Stats grid ────────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: wide2 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: wide2 ? 1.35 : 1.3,
            children: stats,
          ),
          const SizedBox(height: 24),

          // ── Quick Access Panel (matching Pharm) ──────────────────────────
          _quickAccessPanel(wide2),
          const SizedBox(height: 24),

          // ── Sales Trend ──────────────────────────────────────────────────
          _sectionHeader('Sales Trend', () => context.go('/dashboard/reports/sales')),
          const SizedBox(height: 12),
          _salesTrendChart(salesAsync),
          const SizedBox(height: 24),

          // ── Top Items Today ───────────────────────────────────────────────
          _sectionHeader('Top Items Today', () => context.go('/dashboard/reports/sales')),
          const SizedBox(height: 12),
          salesAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            )),
            error: (e, _) => _glassRow(child: Text('Failed to load sales data',
                style: TextStyle(color: context.hintColor, fontSize: 13))),
            data: (report) {
              if (report.topItems.isEmpty) {
                return _glassRow(child: Text('No sales today',
                    style: TextStyle(color: context.hintColor, fontSize: 13)));
              }
              return Column(children: report.topItems.take(4).map((item) =>
                _glassRow(child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.medication_rounded, color: Color(0xFF0D9488), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${item.qty} units sold', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  ])),
                  Text(_fmt(item.revenue),
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 14)),
                ]))
              ).toList());
            },
          ),
          const SizedBox(height: 24),

          // ── Low Stock Alerts ──────────────────────────────────────────────
          _sectionHeader('Low Stock Alerts', () => context.go('/dashboard/inventory')),
          const SizedBox(height: 12),
          invAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            )),
            error: (e, _) => _glassRow(child: Text('Failed to load inventory data',
                style: TextStyle(color: context.hintColor, fontSize: 13))),
            data: (report) {
              if (report.lowStockItems.isEmpty) {
                return _glassRow(child: Text('All items adequately stocked',
                    style: TextStyle(color: context.hintColor, fontSize: 13)));
              }
              return Column(children: report.lowStockItems.take(4).map((s) {
                final pct = s.stock / (s.lowStockThreshold > 0 ? s.lowStockThreshold : 1);
                final c   = pct < 0.3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
                return _glassRow(child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: c.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.warning_amber_rounded, color: c, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Threshold: ${s.lowStockThreshold}', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${s.stock} units', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ]));
              }).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: _PressableCard(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha:0.25)),
              ),
              child: Column(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Quick Access Panel (matching Pharm dashboard) ─────────────────────────

  Widget _quickAccessPanel(bool wide) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.dashboard_rounded, color: EnhancedTheme.primaryTeal, size: 18),
              const SizedBox(width: 8),
              Text('Quick Access',
                  style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            wide
                ? Row(children: [
                    Expanded(child: _quickAccessCard(
                      'Dispensing Management', 'Track & Analyze',
                      Icons.medication_rounded, EnhancedTheme.primaryTeal,
                      [(Icons.list_alt_rounded, 'Disp. Log', '/dashboard/dispensing-log'),
                       (Icons.point_of_sale_rounded, 'New Sale', '/dashboard/pos')],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'Store Operations', 'Retail & Wholesale',
                      Icons.storefront_rounded, EnhancedTheme.successGreen,
                      [(Icons.shopping_cart_rounded, 'Retail', '/dashboard/pos'),
                       (Icons.store_rounded, 'Wholesale', '/dashboard/wholesale-pos')],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'Reports & Analytics', 'Business Insights',
                      Icons.analytics_rounded, EnhancedTheme.accentCyan,
                      [(Icons.today_rounded, 'Daily Sales', '/dashboard/reports/sales'),
                       (Icons.calendar_month_rounded, 'Monthly', '/dashboard/reports/profit')],
                    )),
                  ])
                : Column(children: [
                    _quickAccessCard(
                      'Dispensing Management', 'Track & Analyze',
                      Icons.medication_rounded, EnhancedTheme.primaryTeal,
                      [(Icons.list_alt_rounded, 'Disp. Log', '/dashboard/dispensing-log'),
                       (Icons.point_of_sale_rounded, 'New Sale', '/dashboard/pos')],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'Store Operations', 'Retail & Wholesale',
                      Icons.storefront_rounded, EnhancedTheme.successGreen,
                      [(Icons.shopping_cart_rounded, 'Retail', '/dashboard/pos'),
                       (Icons.store_rounded, 'Wholesale', '/dashboard/wholesale-pos')],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'Reports & Analytics', 'Business Insights',
                      Icons.analytics_rounded, EnhancedTheme.accentCyan,
                      [(Icons.today_rounded, 'Daily Sales', '/dashboard/reports/sales'),
                       (Icons.calendar_month_rounded, 'Monthly', '/dashboard/reports/profit')],
                    ),
                  ]),
          ]),
        ),
      ),
    );
  }

  Widget _quickAccessCard(String title, String subtitle, IconData icon, Color color, List<(IconData, String, String)> actions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: context.labelColor, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text(subtitle, style: TextStyle(color: context.subLabelColor, fontSize: 9), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 4),
          Icon(icon, color: color.withValues(alpha: 0.4), size: 20),
        ]),
        const SizedBox(height: 10),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () => context.go(a.$3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(a.$1, color: color, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a.$2, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Sales Trend Chart ────────────────────────────────────────────────────

  Widget _salesTrendChart(AsyncValue salesAsync) {
    return salesAsync.when(
      loading: () => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor)),
            child: const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2)),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (report) {
        final topItems = report.topItems ?? [];
        if (topItems.isEmpty) return const SizedBox.shrink();

        final maxRevenue = topItems.fold<double>(0, (max, item) => item.revenue > max ? item.revenue : max);
        if (maxRevenue <= 0) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Today\'s Top Revenue Items',
                      style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_fmt(report.totalRevenue ?? 0),
                      style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 16),
                ...topItems.take(5).map((item) {
                  final pct = item.revenue / maxRevenue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(item.name,
                          style: TextStyle(color: context.subLabelColor, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.7 + 0.3 * pct)),
                          minHeight: 12),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 70, child: Text(_fmt(item.revenue),
                          style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right)),
                    ]),
                  );
                }),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      GestureDetector(
        onTap: onSeeAll,
        child: const Text('See all', style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _buildProfileMenu(String role) {
    final isAdmin     = role == 'Admin' || role == 'Manager';
    final isWholesale = role.contains('Wholesale') || isAdmin;
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E293B),
      onSelected: (val) {
        switch (val) {
          case 'settings':   context.go('/dashboard/settings');    break;
          case 'admin':      context.go('/admin-dashboard');       break;
          case 'wholesale':  context.go('/wholesale-dashboard');   break;
          case 'reports':    context.go('/dashboard/reports');     break;
          case 'logout':     _logout();                            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF0D9488).withValues(alpha:0.2),
            child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U',
                style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const Text('Logged in', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ])),
        const PopupMenuDivider(),
        _menuItem('settings',  Icons.settings_outlined,       'Settings'),
        _menuItem('reports',   Icons.bar_chart_outlined,      'Reports'),
        if (isAdmin)
          _menuItem('admin',     Icons.admin_panel_settings_outlined, 'Admin Dashboard'),
        if (isWholesale)
          _menuItem('wholesale', Icons.store_outlined,         'Wholesale Dashboard'),
        const PopupMenuDivider(),
        _menuItem('logout',    Icons.logout_rounded,          'Sign Out',  color: const Color(0xFFEF4444)),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0D9488), width: 2),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF0D9488).withValues(alpha:0.15),
          child: Text(
            role.isNotEmpty ? role[0].toUpperCase() : 'U',
            style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 18),
          ),
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

  Widget _glassRow({required Widget child}) {
    return ClipRRect(
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
          child: child,
        ),
      ),
    );
  }
}

// ── Pressable card (scale on tap) ────────────────────────────────────────────

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// ── More Features Bottom Sheet ────────────────────────────────────────────────

class _MoreFeaturesSheet extends StatelessWidget {
  final bool isAdmin;
  final bool isWholesale;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _MoreFeaturesSheet({
    required this.isAdmin,
    required this.isWholesale,
    required this.onNavigate,
    required this.onLogout,
  });

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
            // Handle
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('More Features', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),

            // Reports section
            _sectionLabel(context, 'Reports'),
            const SizedBox(height: 8),
            Row(children: [
              _featureCard(context, Icons.show_chart,          'Sales',      EnhancedTheme.successGreen, '/dashboard/reports/sales'),
              const SizedBox(width: 10),
              _featureCard(context, Icons.inventory_2_outlined, 'Inventory', EnhancedTheme.infoBlue,    '/dashboard/reports/inventory'),
              const SizedBox(width: 10),
              _featureCard(context, Icons.people_outline,       'Customers', EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
              const SizedBox(width: 10),
              _featureCard(context, Icons.trending_up,          'Profit',    EnhancedTheme.warningAmber, '/dashboard/reports/profit'),
            ]),
            const SizedBox(height: 20),

            // Dashboards section
            _sectionLabel(context, 'Dashboards'),
            const SizedBox(height: 8),
            Row(children: [
              _featureCard(context, Icons.storefront_outlined,  'Retail',    EnhancedTheme.primaryTeal, '/dashboard'),
              const SizedBox(width: 10),
              if (isAdmin) ...[
                _featureCard(context, Icons.admin_panel_settings_outlined, 'Admin', EnhancedTheme.errorRed, '/admin-dashboard'),
                const SizedBox(width: 10),
              ],
              if (isWholesale) ...[
                _featureCard(context, Icons.store_outlined, 'Wholesale', EnhancedTheme.accentCyan, '/wholesale-dashboard'),
                const SizedBox(width: 10),
              ],
              _featureCard(context, Icons.settings_outlined, 'Settings', context.subLabelColor, '/dashboard/settings'),
            ]),
            const SizedBox(height: 20),

            // Logout
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

  Widget _featureCard(BuildContext context, IconData icon, String label, Color color, String route) {
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
