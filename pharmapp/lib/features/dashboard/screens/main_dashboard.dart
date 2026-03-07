import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/dashboard_card.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _selectedIndex = 0;

  // ── Mock data ──────────────────────────────────────────────────────────────

  static const _stats = [
    {'title': "Today's Revenue", 'value': '₹12,450',  'sub': '+8% from yesterday', 'icon': Icons.monetization_on,  'color': Color(0xFF10B981), 'trend': '+8%',  'pos': true},
    {'title': 'Items Sold',      'value': '84',        'sub': 'Today',              'icon': Icons.shopping_bag,      'color': Color(0xFF3B82F6), 'trend': '+12%', 'pos': true},
    {'title': 'Low Stock',       'value': '7',         'sub': 'Need restocking',    'icon': Icons.warning_amber,     'color': Color(0xFFF59E0B), 'trend': null,   'pos': false},
    {'title': 'Customers',       'value': '152',       'sub': 'Registered total',   'icon': Icons.people,            'color': Color(0xFF8B5CF6), 'trend': '+3',   'pos': true},
  ];

  static const _recentSales = [
    {'inv': 'INV-2026-001', 'cust': 'John Doe',     'amt': '₹2,450',  'paid': true,  'ws': false, 'time': '10 min ago'},
    {'inv': 'INV-2026-002', 'cust': 'Walk-in',       'amt': '₹850',   'paid': true,  'ws': false, 'time': '32 min ago'},
    {'inv': 'INV-2026-003', 'cust': 'City Clinic',   'amt': '₹18,200','paid': false, 'ws': true,  'time': '1 hr ago'},
    {'inv': 'INV-2026-004', 'cust': 'Priya Sharma',  'amt': '₹1,100', 'paid': true,  'ws': false, 'time': '2 hr ago'},
  ];

  static const _lowStock = [
    {'name': 'Paracetamol 500mg',  'brand': 'Cipla',     'stock': 5, 'min': 20},
    {'name': 'Amoxicillin 250mg',  'brand': 'Sun Pharma','stock': 3, 'min': 15},
    {'name': 'Metformin 500mg',    'brand': 'USV',       'stock': 8, 'min': 25},
    {'name': 'Omeprazole 20mg',    'brand': 'Alkem',     'stock': 2, 'min': 10},
  ];

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _onNavTap(int i) {
    setState(() => _selectedIndex = i);
    switch (i) {
      case 1: context.go('/dashboard/pos');              break;
      case 2: context.go('/dashboard/inventory');        break;
      case 3: context.go('/dashboard/customers');        break;
      case 4: context.go('/dashboard/reports');           break;
    }
  }

  void _logout() {
    ref.read(authServiceProvider).logout();
    context.go('/login');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
            color: const Color(0xFF0D9488).withOpacity(0.15),
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
              icon: Icon(Icons.logout_rounded, color: Colors.white.withOpacity(0.4)),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_outlined),          selectedIcon: Icon(Icons.home),             label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale),    label: Text('POS')),
        NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined),   selectedIcon: Icon(Icons.inventory_2),      label: Text('Stock')),
        NavigationRailDestination(icon: Icon(Icons.people_outline),          selectedIcon: Icon(Icons.people),           label: Text('Customers')),
        NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined),      selectedIcon: Icon(Icons.bar_chart),        label: Text('Reports')),
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

  Widget _content() {
    // For index > 0, navigation already happened via go_router.
    // Always render home content (sub-screens handle their own routes).
    return _homeContent();
  }

  Widget _homeContent() {
    final user  = ref.watch(currentUserProvider);
    final wide2 = MediaQuery.of(context).size.width > 600;
    final hour  = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting!', style: TextStyle(color: context.subLabelColor, fontSize: 13)),
              const SizedBox(height: 2),
              Text(user?.phoneNumber ?? 'User', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(color: context.hintColor, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () => context.go('/dashboard/settings'),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0D9488), width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF0D9488).withOpacity(0.15),
                  child: Text(
                    (user?.role ?? 'U').isNotEmpty ? (user!.role[0]).toUpperCase() : 'U',
                    style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            ),
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
            _quickBtn(Icons.settings,           'Settings',   Colors.white38,          () => context.go('/dashboard/settings')),
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
            children: _stats.map((s) => DashboardCard(
              title:    s['title']  as String,
              value:    s['value']  as String,
              subtitle: s['sub']    as String,
              icon:     s['icon']   as IconData,
              color:    s['color']  as Color,
              trend:    s['trend']  as String?,
              trendPositive: s['pos'] as bool,
            )).toList(),
          ),
          const SizedBox(height: 24),

          // ── Recent sales ──────────────────────────────────────────────────
          _sectionHeader('Recent Sales', () => context.go('/dashboard/reports/sales')),
          const SizedBox(height: 12),
          ..._recentSales.map(_saleRow),
          const SizedBox(height: 24),

          // ── Low stock ─────────────────────────────────────────────────────
          _sectionHeader('Low Stock Alerts', () => context.go('/dashboard/inventory')),
          const SizedBox(height: 12),
          ..._lowStock.map(_lowStockRow),
        ],
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 5),
                Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
      GestureDetector(
        onTap: onSeeAll,
        child: const Text('See all', style: TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _saleRow(Map<String, dynamic> s) {
    final paid = s['paid'] as bool;
    final ws   = s['ws']   as bool;
    final c    = ws ? const Color(0xFF06B6D4) : const Color(0xFF0D9488);

    return _glassRow(child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(ws ? Icons.business : Icons.person_outline, color: c, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s['inv'] as String, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
        Text(s['cust'] as String, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(s['amt'] as String, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 14)),
        _statusChip(paid ? 'Paid' : 'Pending', paid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
      ]),
    ]));
  }

  Widget _lowStockRow(Map<String, dynamic> s) {
    final stock = s['stock'] as int;
    final min   = s['min']   as int;
    final c     = (stock / min) < 0.3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return _glassRow(child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.warning_amber_rounded, color: c, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s['name'] as String, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
        Text(s['brand'] as String, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$stock units', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
        Text('Min: $min', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
      ]),
    ]));
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
