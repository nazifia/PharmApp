import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'widgets/split_payment_dialog.dart';

// Note: A real app needs a domain model for 'PendingSale' and WebSocket/Server-Sent-Events state
class CashierQueueScreen extends StatelessWidget {
  const CashierQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold UI mocking a live queue of Dispenser requests
    final currency = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier - Pending Transactions'),
        actions: [
           IconButton(
             icon: const Icon(Icons.refresh), 
             onPressed: () { /* Force refresh queue */ } 
           ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Awaiting Payment (3)', 
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 180,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 3, // Mock count
                itemBuilder: (context, index) {
                  final totalAmount = (index + 1) * 45.50; // Mock amount
                  final dispenserName = ['Alice P.', 'Bob S.', 'Charlie M.'][index];

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // Open the Split Payment Dialog when clicked to process the sale
                        SplitPaymentDialog.show(context, totalAmount);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sale #${104 - index}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Pending',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'Dispensed by: $dispenserName',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currency.format(totalAmount),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
