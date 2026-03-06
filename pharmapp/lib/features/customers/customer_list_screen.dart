import 'package:flutter/material.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Database'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Customer'),
            onPressed: () {},
          )
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final balance = (index % 3 == 0) ? -150.00 : 500.00; // Mock negative balances
          final isNegative = balance < 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
            ),
            title: const Text('John Doe', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('+1 (555) 123-4567'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Wallet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  isNegative ? '-\$${balance.abs()}' : '\$$balance',
                  style: TextStyle(
                    color: isNegative ? Colors.red : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            onTap: () {
              // Open Customer detail to add funds / process credit
            },
          );
        },
      ),
    );
  }
}
