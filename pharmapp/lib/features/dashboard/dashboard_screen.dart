import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  final Widget child; // Injected via GoRouter's ShellRoute
  
  const DashboardScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Determine screen width for adaptive layout
    final isTablet = MediaQuery.of(context).size.width >= 768;
    
    // Read the current location from GoRouter state
    final String location = GoRouterState.of(context).uri.path;
    
    // Determine selected index
    int selectedIndex = 0;
    if (location.startsWith('/inventory')) {
      selectedIndex = 1;
    } else if (location.startsWith('/customers')) {
      selectedIndex = 2;
    } else if (location.startsWith('/cashier')) {
      // Treating Cashier exactly like POS in nav for simplicity right now
      selectedIndex = 0; 
    } 
    // Index 3 (Reports) is a placeholder without a route

    final destinations = const [
      NavigationDestination(icon: Icon(PhosphorIconsRegular.shoppingCart), label: 'POS'),
      NavigationDestination(icon: Icon(PhosphorIconsRegular.pill), label: 'Inventory'),
      NavigationDestination(icon: Icon(PhosphorIconsRegular.users), label: 'Customers'),
      NavigationDestination(icon: Icon(PhosphorIconsRegular.chartLineUp), label: 'Reports'),
    ];

    void onDestinationSelected(int idx) {
      switch (idx) {
        case 0:
          // A real app would decide pos or cashier based on User Role. Mock to POS
          context.go('/pos');
          break;
        case 1:
          context.go('/inventory');
          break;
        case 2:
          context.go('/customers');
          break;
        case 3:
          // Placeholder
          break;
      }
    }

    return Scaffold(
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: destinations.map((d) => NavigationRailDestination(
                icon: d.icon,
                label: Text(d.label),
              )).toList(),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 4,
            ),
          
          if (isTablet) const VerticalDivider(thickness: 1, width: 1),
          
          // Main Content Area
          Expanded(
            child: child, 
          ),
        ],
      ),
      bottomNavigationBar: !isTablet ? NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        elevation: 10,
        backgroundColor: Colors.white,
      ) : null,
    );
  }
}

