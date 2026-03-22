import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import '../providers/customer_provider.dart';
import '../../pos/providers/cart_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idStr         = GoRouterState.of(context).pathParameters['id'] ?? '0';
    final id            = int.tryParse(idStr) ?? 0;
    final customerAsync = ref.watch(customerDetailProvider(id));
    final salesAsync    = ref.watch(customerSalesProvider(id));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: customerAsync.when(
          loading: () => Column(children: [
            _header(context, null, id, ref),
            const Expanded(child: Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))),
          ]),
          error: (e, _) => Column(children: [
            _header(context, null, id, ref),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: context.subLabelColor), textAlign: TextAlign.center),
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

  Widget _header(BuildContext context, Customer? customer, int id, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/customers')),
      Expanded(child: Text('Customer Profile',
          style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600))),
      if (customer != null) ...[
        IconButton(
          icon: Icon(Icons.edit_outlined, color: context.iconOnBg.withValues(alpha: 0.7)),
          onPressed: () => _showEditSheet(context, ref, customer)),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed.withValues(alpha: 0.7)),
          onPressed: () => _confirmDelete(context, ref, customer)),
      ],
    ]),
  );

  Widget _buildContent(BuildContext context, WidgetRef ref, Customer customer,
      AsyncValue<List<CustomerSale>> salesAsync) {
    final isWholesale = customer.isWholesale;
    final accentColor = isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal;

    return Column(children: [
      _header(context, customer, customer.id, ref),
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
            Expanded(child: _metricCard(context, 'Total Spent',
                customer.totalSpent != null ? '₦${customer.totalSpent!.toStringAsFixed(0)}' : '—',
                EnhancedTheme.primaryTeal, Icons.payments_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard(context, 'Wallet',
                '₦${customer.walletBalance.toStringAsFixed(0)}',
                EnhancedTheme.successGreen, Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard(context, 'Purchases',
                '${customer.totalPurchases}',
                EnhancedTheme.accentCyan, Icons.shopping_bag_rounded)),
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
                onPressed: () => _showPayDebtDialog(context, ref, customer),
                child: const Text('Pay Now', style: TextStyle(color: EnhancedTheme.errorRed))),
            ])),
          ],
          const SizedBox(height: 16),

          // ── Contact details ──────────────────────────────────────────────────
          _sectionTitle(context, 'Contact Details'),
          _glassCard(context, child: Column(children: [
            _detailRow(context, 'Phone', customer.phone),
            if (customer.email != null && customer.email!.isNotEmpty) ...[
              _divider(context),
              _detailRow(context, 'Email', customer.email!),
            ],
            if (customer.address != null && customer.address!.isNotEmpty) ...[
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
          _sectionTitle(context, 'Purchase History'),
          salesAsync.when(
            loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2))),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Could not load sales history',
                  style: TextStyle(color: context.subLabelColor, fontSize: 12))),
            data: (sales) => sales.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No purchase history',
                        style: TextStyle(color: context.hintColor, fontSize: 13)))
                : Column(children: sales.map((p) => _purchaseRow(context, p)).toList()),
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
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _startNewSale(context, ref, customer),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
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

  // ── New sale from customer profile ─────────────────────────────────────────

  void _startNewSale(BuildContext context, WidgetRef ref, Customer customer) {
    // Pre-select this customer in POS and clear any stale cart
    ref.read(cartProvider.notifier).clearCart();
    ref.read(selectedCustomerProvider.notifier).state = SelectedCustomer(
      id: customer.id,
      name: customer.name,
      walletBalance: customer.walletBalance,
    );

    // Route to the right POS based on customer type
    final posRoute = customer.isWholesale ? '/dashboard/wholesale-pos' : '/dashboard/pos';
    context.push(posRoute);
  }

  // ── Edit customer sheet ─────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, WidgetRef ref, Customer customer) {
    final nameCtrl    = TextEditingController(text: customer.name);
    final phoneCtrl   = TextEditingController(text: customer.phone);
    final emailCtrl   = TextEditingController(text: customer.email ?? '');
    final addressCtrl = TextEditingController(text: customer.address ?? '');
    bool isWholesale  = customer.isWholesale;
    final formKey     = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: context.borderColor)),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    Text('Edit Customer',
                        style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    _sheetField(nameCtrl, 'Full Name / Business Name', Icons.person_rounded, context,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                    const SizedBox(height: 14),
                    _sheetField(phoneCtrl, 'Phone Number', Icons.phone_rounded, context,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null),
                    const SizedBox(height: 14),
                    _sheetField(emailCtrl, 'Email (optional)', Icons.email_outlined, context,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _sheetField(addressCtrl, 'Address (optional)', Icons.location_on_outlined, context),
                    const SizedBox(height: 14),
                    Row(children: [
                      Text('Type:', style: TextStyle(color: context.labelColor, fontSize: 13)),
                      const SizedBox(width: 12),
                      _typeChip(ctx, 'Retail', !isWholesale, () => setSheetState(() => isWholesale = false)),
                      const SizedBox(width: 8),
                      _typeChip(ctx, 'Wholesale', isWholesale, () => setSheetState(() => isWholesale = true)),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final data = {
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'is_wholesale': isWholesale,
                            'email': emailCtrl.text.trim(),
                            'address': addressCtrl.text.trim(),
                          };
                          final updated = await ref.read(customerNotifierProvider.notifier)
                              .updateCustomer(customer.id, data);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(updated != null ? 'Customer updated' : 'Update failed'),
                              backgroundColor: updated != null ? EnhancedTheme.successGreen : EnhancedTheme.errorRed));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Save Changes'),
                      )),
                    const SizedBox(height: 8),
                  ])),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation ─────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Customer', style: TextStyle(color: context.labelColor)),
        content: Text('Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            final success = await ref.read(customerNotifierProvider.notifier).deleteCustomer(customer.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success ? 'Customer deleted' : 'Delete failed'),
                backgroundColor: success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed));
              if (success) { if (context.canPop()) { context.pop(); } else { context.go('/dashboard/customers'); } }
            }
          }, child: const Text('Delete', style: TextStyle(color: EnhancedTheme.errorRed))),
        ],
      ),
    );
  }

  // ── Record debt payment dialog ──────────────────────────────────────────────

  void _showPayDebtDialog(BuildContext context, WidgetRef ref, Customer customer) {
    final amountCtrl = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Record Debt Payment', style: TextStyle(color: context.labelColor)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Outstanding: ₦${customer.outstandingDebt.toStringAsFixed(2)}',
                style: const TextStyle(color: EnhancedTheme.errorRed, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: context.labelColor),
              decoration: InputDecoration(
                hintText: 'Payment amount',
                prefixText: '₦ ',
                filled: true,
                fillColor: context.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 12),
            Text('Method:', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: ['cash', 'pos', 'transfer'].map((m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m.toUpperCase(), style: TextStyle(fontSize: 11)),
                selected: method == m,
                onSelected: (_) => setDialogState(() => method = m),
                selectedColor: EnhancedTheme.primaryTeal,
                labelStyle: TextStyle(color: method == m ? Colors.white : context.subLabelColor),
              ),
            )).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: context.hintColor))),
            TextButton(onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              final success = await ref.read(walletNotifierProvider(customer.id).notifier)
                  .recordPayment(amount: amount, method: method);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Payment of ₦${amount.toStringAsFixed(2)} recorded' : 'Payment failed'),
                  backgroundColor: success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed));
              }
            }, child: const Text('Record Payment', style: TextStyle(color: EnhancedTheme.primaryTeal))),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

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
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.hintColor, fontSize: 10), textAlign: TextAlign.center),
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

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon, BuildContext context,
      {TextInputType? keyboardType, String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: TextStyle(color: context.labelColor),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.hintColor),
          prefixIcon: Icon(icon, color: context.hintColor, size: 20),
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      );

  Widget _typeChip(BuildContext context, String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? EnhancedTheme.primaryTeal : context.cardColor,
        borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(color: selected ? Colors.white : context.hintColor, fontSize: 13, fontWeight: FontWeight.w600))));
}
