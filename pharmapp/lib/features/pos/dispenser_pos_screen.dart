import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inventory/inventory_screen.dart'; // Re-use the inventory as the left pane typically
import 'widgets/cart_summary_panel.dart';

class DispenserPosScreen extends ConsumerWidget {
  const DispenserPosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine screen width for adaptive layout
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale - Dispenser'),
        actions: [
          // If on mobile, show a cart icon to open the summary panel as a modal
          if (!isTablet)
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                // Open Cart Summary in a bottom sheet for mobile
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const CartSummaryPanel(),
                );
              },
            )
        ],
      ),
      body: Row(
        children: [
          // On both Mobile and Tablet, the Inventory view is the primary interaction point
          // for scanning and searching for products to add to the cart.
          const Expanded(
            flex: 2,
            child: InventoryScreen(), // Refactored later to remove its own Scaffold
          ),

          if (isTablet) const VerticalDivider(thickness: 1, width: 1),

          // On Tablet/Web, the Cart Summary is permanently pinned to the right
          if (isTablet)
            Expanded(
              flex: 1,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: const CartSummaryPanel(), // Note: Needs "Send to Cashier" logic injected
              ),
            ),
        ],
      ),
    );
  }
}
