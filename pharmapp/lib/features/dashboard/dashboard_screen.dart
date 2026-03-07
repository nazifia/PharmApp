import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class DashboardScreen extends StatelessWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final String location = GoRouterState.of(context).uri.path;

    int selectedIndex = 0;
    if (location.contains('/inventory') || location.contains('/item')) {
      selectedIndex = 1;
    } else if (location.contains('/customers') || location.contains('/customer') || location.contains('/wallet')) {
      selectedIndex = 2;
    } else if (location.contains('/reports')) {
      selectedIndex = 3;
    } else if (location.contains('/settings')) {
      selectedIndex = 4;
    }

    void onDestinationSelected(int idx) {
      switch (idx) {
        case 0: context.go('/dashboard/pos');       break;
        case 1: context.go('/dashboard/inventory'); break;
        case 2: context.go('/dashboard/customers'); break;
        case 3: context.go('/dashboard/reports/sales'); break;
        case 4: context.go('/dashboard/settings'); break;
      }
    }

    const destinations = [
      (icon: Icons.point_of_sale_rounded,  label: 'POS'),
      (icon: Icons.inventory_2_rounded,     label: 'Inventory'),
      (icon: Icons.people_rounded,          label: 'Customers'),
      (icon: Icons.bar_chart_rounded,       label: 'Reports'),
      (icon: Icons.settings_rounded,        label: 'Settings'),
    ];

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              backgroundColor: const Color(0xFF0F172A),
              selectedIconTheme: const IconThemeData(color: EnhancedTheme.primaryTeal),
              selectedLabelTextStyle: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11),
              unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.4)),
              unselectedLabelTextStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              destinations: destinations.map((d) => NavigationRailDestination(
                icon: Icon(d.icon),
                label: Text(d.label),
              )).toList(),
            ),
          if (isTablet) VerticalDivider(width: 1, color: Colors.white.withOpacity(0.1)),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isTablet ? null : NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: EnhancedTheme.primaryTeal.withOpacity(0.2),
        destinations: destinations.map((d) => NavigationDestination(
          icon: Icon(d.icon, color: Colors.white54),
          selectedIcon: Icon(d.icon, color: EnhancedTheme.primaryTeal),
          label: d.label,
        )).toList(),
      ),
    );
  }
}
