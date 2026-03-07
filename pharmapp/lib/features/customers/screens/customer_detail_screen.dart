import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerId = GoRouterState.of(context).pathParameters['id'] ?? '1';

    final customer = {
      'id': int.tryParse(customerId) ?? 1,
      'name': 'Adaeze Okafor',
      'phone': '+2348012345678',
      'email': 'adaeze@example.com',
      'address': '12 Broad Street, Lagos Island',
      'type': 'Retail',
      'wallet': 1500.0,
      'debt': 0.0,
      'totalSpent': 28450.0,
      'purchases': 24,
      'joinDate': 'Jan 2024',
      'lastVisit': '2 days ago',
    };

    final recentPurchases = [
      {'date': 'Mar 4, 2026', 'items': 3, 'total': 1250.0, 'status': 'Paid'},
      {'date': 'Feb 28, 2026', 'items': 1, 'total': 450.0,  'status': 'Paid'},
      {'date': 'Feb 20, 2026', 'items': 5, 'total': 3200.0, 'status': 'Paid'},
      {'date': 'Feb 10, 2026', 'items': 2, 'total': 750.0,  'status': 'Paid'},
    ];

    final isWholesale = customer['type'] == 'Wholesale';
    final walletBal = customer['wallet'] as double;
    final debt = customer['debt'] as double;

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1]))),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
                  const Expanded(child: Text('Customer Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Edit customer – coming soon'))),
                  ),
                ]),
              ),

              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Profile hero
                  _glassCard(child: Row(children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: (isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal).withOpacity(0.2),
                      child: Text(
                        (customer['name'] as String)[0].toUpperCase(),
                        style: TextStyle(
                          color: isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal,
                          fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(customer['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(customer['phone'] as String, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                      const SizedBox(height: 8),
                      _chip(customer['type'] as String, isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal),
                    ])),
                  ])),
                  const SizedBox(height: 16),

                  // Metrics
                  Row(children: [
                    Expanded(child: _metricCard('Total Spent', '₹${(customer['totalSpent'] as double).toStringAsFixed(0)}', EnhancedTheme.primaryTeal, Icons.payments_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _metricCard('Wallet', '₹${walletBal.toStringAsFixed(0)}', EnhancedTheme.successGreen, Icons.account_balance_wallet_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _metricCard('Purchases', '${customer['purchases']}', EnhancedTheme.accentCyan, Icons.shopping_bag_rounded)),
                  ]),
                  if (debt > 0) ...[
                    const SizedBox(height: 10),
                    _glassCard(child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.errorRed, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Outstanding balance: ₹${debt.toStringAsFixed(2)}',
                          style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600))),
                      TextButton(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Record payment – coming soon'))),
                        child: const Text('Pay Now', style: TextStyle(color: EnhancedTheme.errorRed)),
                      ),
                    ])),
                  ],
                  const SizedBox(height: 16),

                  // Contact details
                  _sectionTitle('Contact Details'),
                  _glassCard(child: Column(children: [
                    _detailRow('Phone', customer['phone'] as String),
                    _divider(),
                    _detailRow('Email', customer['email'] as String),
                    _divider(),
                    _detailRow('Address', customer['address'] as String),
                    _divider(),
                    _detailRow('Member Since', customer['joinDate'] as String),
                    _divider(),
                    _detailRow('Last Visit', customer['lastVisit'] as String),
                  ])),
                  const SizedBox(height: 16),

                  // Recent purchases
                  _sectionTitle('Recent Purchases'),
                  ...recentPurchases.map((p) => _purchaseRow(p)),
                  const SizedBox(height: 16),

                  // Actions
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(
                      onPressed: () => context.push('/wallet/${customer['id']}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                      label: const Text('Wallet'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('New sale – coming soon'))),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EnhancedTheme.primaryTeal,
                        side: const BorderSide(color: EnhancedTheme.primaryTeal),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: const Text('New Sale'),
                    )),
                  ]),
                  const SizedBox(height: 24),
                ]),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.11)),
        ),
        child: child,
      ),
    ),
  );

  Widget _metricCard(String label, String value, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  Widget _purchaseRow(Map<String, dynamic> p) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['date'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${p['items']} items', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${(p['total'] as double).toStringAsFixed(0)}',
                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(p['status'] as String, style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 10)),
          ]),
        ]),
      ),
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
    ]),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
  );

  Widget _divider() => Divider(height: 1, color: Colors.white.withOpacity(0.07));

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
