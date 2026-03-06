import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';

class CartSummaryPanel extends ConsumerWidget {
  const CartSummaryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final total = ref.read(cartProvider.notifier).cartTotal;
    final currency = NumberFormat.currency(symbol: '\$');

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Current Sale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  title: Text(item.item.name),
                  subtitle: Text('${item.quantity} x ${currency.format(item.item.price)}'),
                  trailing: Text(currency.format(item.subtotal)),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
             padding: const EdgeInsets.all(24.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('Total', style: Theme.of(context).textTheme.titleLarge),
                     Text(
                       currency.format(total), 
                       style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                     ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 ElevatedButton(
                   onPressed: cartItems.isEmpty ? null : () {
                     // Trigger Payment / Cashier Flow
                   },
                   style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 20),
                   ),
                   child: const Text('Process Payment'),
                 )
               ],
             ),
          )
        ],
      ),
    );
  }
}
