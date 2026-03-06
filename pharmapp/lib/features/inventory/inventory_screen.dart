import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/inventory_provider.dart';
import 'widgets/item_detail_modal.dart';
import '../pos/providers/cart_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the future provider to get the async state of the inventory list
    final inventoryAsyncValue = ref.watch(inventoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () { /* Oepn Camera Scanner */ },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(inventoryListProvider),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar (Client-side filtering to be implemented later)
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by Name, Brand, or scan Barcode (GTIN)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_list, color: Colors.white),
                )
              ),
            ),
            const SizedBox(height: 24),
            
            // Async Inventory Grid
            Expanded(
              child: inventoryAsyncValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Failed to load inventory:\n$error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(inventoryListProvider),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('No items found in inventory.'));
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isLowStock = item.stock <= item.lowStockThreshold;

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: isLowStock ? 4 : 1,
                        color: isLowStock ? Colors.red.shade50 : Colors.white,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                             // Show details modal specifically for POS flow insertion
                             ItemDetailModal.show(context, item);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLowStock ? Colors.red : Theme.of(context).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isLowStock ? 'LOW STOCK' : item.dosageForm,
                                    style: TextStyle(
                                      color: isLowStock ? Colors.white : Theme.of(context).colorScheme.onSecondaryContainer,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.brand,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.stock} in stock',
                                      style: TextStyle(
                                        color: isLowStock ? Colors.red.shade700 : Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    // Quick Add to POS Button
                                    IconButton(
                                      icon: const Icon(Icons.add_shopping_cart),
                                      color: Theme.of(context).colorScheme.primary,
                                      onPressed: item.stock > 0 ? () {
                                         ref.read(cartProvider.notifier).addItem(item);
                                         ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Added ${item.name} to POS Cart.'),
                                              duration: const Duration(seconds: 1),
                                            )
                                         );
                                      } : null,
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ).animate().fade(delay: (index * 50).ms).slideY(begin: 0.1);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
