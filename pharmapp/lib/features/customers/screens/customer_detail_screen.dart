import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idStr      = GoRouterState.of(context).pathParameters['id'] ?? '0';
    final id         = int.tryParse(idStr) ?? 0;
    final customerAsync = ref.watch(customerDetailProvider(id));
    final salesAsync    = ref.watch(customerSalesProvider(id));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: customerAsync.when(
          loading: () => Column(children: [
            _header(context, null, id),
            const Expanded(child: Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))),
          ]),
          error: (e, _) => Column(children: [
            _header(context, null, id),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(customerDetailProvider(id)),
                child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ]))),
          ]),
          data: (customer) => _buildContent(context, ref, customer, salesAsync),
        )),
      ]),
    );
  }

  Widget _header(BuildContext context, Customer? customer, int id) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
          onPressed: () => context.pop()),
      Expanded(child: Text('Customer Profile',
          style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600))),
      if (customer != null)
        IconButton(
          icon: Icon(Icons.edit_outlined, color: context.iconOnBg.withValues(alpha: 0.7)),
          onPressed: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Edit customer — coming soon'))),
        ),
    ]),
  );

  Widget _buildContent(BuildContext context, WidgetRef ref, Customer customer,
      AsyncValue<List<CustomerSale>> salesAsync) {
    final isWholesale = customer.isWholesale;
    final accentColor = isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal;

    return Column(children: [
      _header(context, customer, customer.id),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Profile hero ────────────────────────────────────────────────────
          _glassCard(context, child: Row(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                style: TextStyle(color: accentColor, fontSize: 28, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer.name,
                  style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(customer.phone,
                  style: TextStyle(color: context.subLabelColor, fontSize: 13)),
              const SizedBox(height: 8),
              _chip(customer.type, accentColor),
            ])),
          ])),
          const SizedBox(height: 16),

          // ── Key metrics ─────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _metricCard(
              context,
              'Total Spent',
              customer.totalSpent != null
                  ? '₦${customer.totalSpent!.toStringAsFixed(0)}'
                  : '—',
              EnhancedTheme.primaryTeal,
              Icons.payments_rounded,
            )),
            const SizedBox(width: 10),
            Expanded(child: _metricCard(
              context,
              'Wallet',
              '₦${customer.walletBalance.toStringAsFixed(0)}',
              EnhancedTheme.successGreen,
              Icons.account_balance_wallet_rounded,
            )),
            const SizedBox(width: 10),
            Expanded(child: _metricCard(
              context,
              'Purchases',
              '${customer.totalPurchases}',
              EnhancedTheme.accentCyan,
              Icons.shopping_bag_rounded,
            )),
          ]),

          // ── Outstanding debt warning ─────────────────────────────────────────
          if (customer.outstandingDebt > 0) ...[
            const SizedBox(height: 10),
            _glassCard(context, child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.errorRed, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Outstanding balance: ₦${customer.outstandingDebt.toStringAsFixed(2)}',
                style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600))),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Record payment — coming soon'))),
                child: const Text('Pay Now', style: TextStyle(color: EnhancedTheme.errorRed))),
            ])),
          ],
          const SizedBox(height: 16),

          // ── Contact details ──────────────────────────────────────────────────
          _sectionTitle(context, 'Contact Details'),
          _glassCard(context, child: Column(children: [
            _detailRow(context, 'Phone', customer.phone),
            if (customer.email != null) ...[
              _divider(context),
              _detailRow(context, 'Email', customer.email!),
            ],
            if (customer.address != null) ...[
              _divider(context),
              _detailRow(context, 'Address', customer.address!),
            ],
            if (customer.joinDate != null) ...[
              _divider(context),
              _detailRow(context, 'Member Since', customer.joinDate!),
            ],
            if (customer.lastVisit != null) ...[
              _divider(context),
              _detailRow(context, 'Last Visit', customer.lastVisit!),
            ],
          ])),
          const SizedBox(height: 16),

          // ── Recent purchases ─────────────────────────────────────────────────
          _sectionTitle(context, 'Recent Purchases'),
          salesAsync.when(
            loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2),
                )),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Could not load sales history',
                  style: TextStyle(color: context.subLabelColor, fontSize: 12))),
            data: (sales) => sales.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No purchase history',
                        style: TextStyle(color: context.hintColor, fontSize: 13)))
                : Column(children: sales.take(10).map((p) => _purchaseRow(context, p)).toList()),
          ),
          const SizedBox(height: 16),

          // ── Actions ─────────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => context.push('/customer/${customer.id}/wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
              label: const Text('Wallet'),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('New sale — coming soon'))),
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.primaryTeal,
                side: const BorderSide(color: EnhancedTheme.primaryTeal),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: const Text('New Sale'),
            )),
          ]),
          const SizedBox(height: 24),
        ]),
      )),
    ]);
  }

  Widget _purchaseRow(BuildContext context, CustomerSale p) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor)),
        child: Row(children: [
          Icon(Icons.receipt_long_rounded, color: context.hintColor, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.date,
                style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${p.items} items',
                style: TextStyle(color: context.subLabelColor, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₦${p.total.toStringAsFixed(0)}',
                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(p.status, style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 10)),
          ]),
        ]),
      ),
    ),
  );

  Widget _glassCard(BuildContext context, {required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor)),
        child: child)));

  Widget _metricCard(BuildContext context, String label, String value, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: context.hintColor, fontSize: 10),
              textAlign: TextAlign.center),
        ]))));

  Widget _detailRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      SizedBox(width: 110,
          child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13))),
      Expanded(child: Text(value,
          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
          textAlign: TextAlign.right)),
    ]));

  Widget _sectionTitle(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)));

  Widget _divider(BuildContext context) => Divider(height: 1, color: context.dividerColor);

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
}
