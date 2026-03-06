import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/cart_provider.dart';
import '../providers/pos_api_provider.dart';
import '../../../shared/models/sale.dart';
class SplitPaymentDialog extends ConsumerStatefulWidget {
  final double totalAmount;

  const SplitPaymentDialog({super.key, required this.totalAmount});

  static Future<void> show(BuildContext context, double totalAmount) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SplitPaymentDialog(totalAmount: totalAmount),
    );
  }

  @override
  ConsumerState<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends ConsumerState<SplitPaymentDialog> {
  final currency = NumberFormat.currency(symbol: '\$');
  
  double _cashAmount = 0.0;
  double _transferAmount = 0.0;
  double _walletAmount = 0.0;

  // We default to Cash handling the full amount initially.
  @override
  void initState() {
    super.initState();
    _cashAmount = widget.totalAmount;
  }

  double get _currentTotal => _cashAmount + _transferAmount + _walletAmount;
  double get _remaining => widget.totalAmount - _currentTotal;
  bool get _isValid => _remaining == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Process Payment',
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total Due: ${currency.format(widget.totalAmount)}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Payment Methods Inputs
            _buildPaymentInput('Cash', Icons.money, _cashAmount, (val) {
              setState(() => _cashAmount = val);
            }),
            const SizedBox(height: 16),
            _buildPaymentInput('Bank Transfer', Icons.account_balance, _transferAmount, (val) {
              setState(() => _transferAmount = val);
            }),
            const SizedBox(height: 16),
            _buildPaymentInput('Customer Wallet', Icons.account_balance_wallet, _walletAmount, (val) {
              setState(() => _walletAmount = val);
            }),

            const SizedBox(height: 32),
            
            // Validation / Remaining Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isValid 
                    ? Colors.green.shade50 
                    : (_remaining < 0 ? Colors.red.shade50 : Colors.orange.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                   color: _isValid 
                      ? Colors.green.shade200 
                      : (_remaining < 0 ? Colors.red.shade200 : Colors.orange.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: _isValid 
                        ? Colors.green.shade700 
                        : (_remaining < 0 ? Colors.red.shade700 : Colors.orange.shade700),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isValid 
                        ? 'Payment Balanced' 
                        : (_remaining < 0 
                            ? 'Overpaid by ${currency.format(_remaining.abs())}' 
                            : 'Remaining: ${currency.format(_remaining)}'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isValid 
                          ? Colors.green.shade900 
                          : (_remaining < 0 ? Colors.red.shade900 : Colors.orange.shade900),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isValid ? _processPayment : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text('Confirm Checkout'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInput(String label, IconData icon, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        Expanded(
          flex: 3,
          child: TextFormField(
            initialValue: value == 0 ? '' : value.toStringAsFixed(2),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null || text.isEmpty) {
                onChanged(parsed ?? 0.0);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    final cartItems = ref.read(cartProvider);
    final checkoutNotifier = ref.read(checkoutProvider.notifier);

    // Map local cart items to the Django expected payload
    final saleItems = cartItems.map((c) => SaleItemPayload(
      barcode: c.item.barcode, // Or c.item.id if using integer IDs
      quantity: c.quantity,
      unitPrice: c.item.price,
    )).toList();

    final payload = CheckoutPayload(
      items: saleItems,
      payments: PaymentPayload(
        cash: _cashAmount,
        bankTransfer: _transferAmount,
        wallet: _walletAmount,
      ),
      totalAmount: widget.totalAmount,
      // customerId: ... would be set here if a customer was attached to the cart
    );

    // Trigger the API Call
    final success = await checkoutNotifier.processCheckout(payload);

    if (!mounted) return;

    if (success) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: const Text('Payment processed and saved successfully.'),
           backgroundColor: Colors.green.shade800,
           behavior: SnackBarBehavior.floating,
         )
       );
       
       // Clear the cart on success
       ref.read(cartProvider.notifier).clearCart(); 
       
       // Close Dialog
       Navigator.pop(context);
    } else {
       // The error state is held in the provider, but we could also show a snackbar here
       final errorState = ref.read(checkoutProvider).error;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Checkout Failed: $errorState'),
           backgroundColor: Colors.red.shade800,
           behavior: SnackBarBehavior.floating,
         )
       );
    }
  }
}

