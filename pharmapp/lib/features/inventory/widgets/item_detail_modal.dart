import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/item.dart';
import '../../pos/providers/cart_provider.dart';

class ItemDetailModal extends ConsumerStatefulWidget {
  final Item item;

  const ItemDetailModal({super.key, required this.item});

  static Future<void> show(BuildContext context, Item item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemDetailModal(item: item),
    );
  }

  @override
  ConsumerState<ItemDetailModal> createState() => _ItemDetailModalState();
}

class _ItemDetailModalState extends ConsumerState<ItemDetailModal> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final isLowStock = widget.item.stock <= widget.item.lowStockThreshold;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Name and Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.brand,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(widget.item.price),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metadata Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceTint.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetaColumn(context, 'Format', widget.item.dosageForm),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildMetaColumn(
                  context, 
                  'In Stock', 
                  '${widget.item.stock}',
                  valueColor: isLowStock ? Colors.red : Colors.green.shade700,
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildMetaColumn(context, 'Barcode', widget.item.barcode),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  '$_quantity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: _quantity < widget.item.stock ? () => setState(() => _quantity++) : null,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Add to Cart Button
          ElevatedButton(
            onPressed: widget.item.stock == 0 ? null : () {
              // Note: The cartProvider currently increments by 1 if existing. 
              // A real robust app needs an addMultiple method, but for now we loop.
              for (var i = 0; i < _quantity; i++) {
                ref.read(cartProvider.notifier).addItem(widget.item);
              }
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added $_quantity ${widget.item.name} to POS Cart.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            child: Text(
              widget.item.stock == 0 ? 'Out of Stock' : 'Add to Cart — ${currency.format(widget.item.price * _quantity)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaColumn(BuildContext context, String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
