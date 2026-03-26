import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

        // Decorative elements
        Positioned(
          top: -40, right: -40,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.06),
            ),
          ),
        ),

        SafeArea(child: customerAsync.when(
          loading: () => Column(children: [
            _header(context, null, id, ref),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  color: EnhancedTheme.primaryTeal,
                  backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text('Loading profile…', style: TextStyle(color: context.subLabelColor, fontSize: 13)),
            ]))),
          ]),
          error: (e, _) => Column(children: [
            _header(context, null, id, ref),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Could not load profile',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(customerDetailProvider(id)),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ]))),
          ]),
          data: (customer) => _buildContent(context, ref, customer, salesAsync),
        )),
      ]),
    );
  }

  Widget _header(BuildContext context, Customer? customer, int id, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
    child: Row(children: [
      IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/customers')),
      Expanded(child: Text('Customer Profile',
          style: GoogleFonts.outfit(
              color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700))),
      if (customer != null) ...[
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.edit_outlined, color: context.iconOnBg, size: 18),
          ),
          onPressed: () => _showEditSheet(context, ref, customer)),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 18),
          ),
          onPressed: () => _confirmDelete(context, ref, customer)),
      ],
    ]),
  );

  Widget _buildContent(BuildContext context, WidgetRef ref, Customer customer,
      AsyncValue<List<CustomerSale>> salesAsync) {
    final isWholesale = customer.isWholesale;
    final accentColor = isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal;
    final initials = customer.name.trim().split(' ')
        .where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

    return Column(children: [
      _header(context, customer, customer.id, ref),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Profile hero ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      accentColor.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Row(children: [
                  // Large avatar
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                      child: Text(initials.isNotEmpty ? initials : '?',
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(customer.name,
                        style: GoogleFonts.outfit(
                            color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.phone_rounded, color: context.subLabelColor, size: 13),
                      const SizedBox(width: 4),
                      Text(customer.phone,
                          style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _chip(customer.type, accentColor,
                          icon: isWholesale ? Icons.store_rounded : Icons.storefront_rounded),
                      if (customer.outstandingDebt > 0) ...[
                        const SizedBox(width: 8),
                        _chip('Has Debt', EnhancedTheme.errorRed, icon: Icons.warning_rounded),
                      ],
                    ]),
                  ])),
                ]),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
          const SizedBox(height: 16),

          // ── Key metrics ─────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _metricCard(context, 'Total Spent',
                customer.totalSpent != null ? '₦${customer.totalSpent!.toStringAsFixed(0)}' : '—',
                EnhancedTheme.primaryTeal, Icons.payments_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard(
                context,
                'Wallet',
                '${customer.walletBalance < 0 ? '-' : ''}₦${customer.walletBalance.abs().toStringAsFixed(0)}',
                customer.walletBalance < 0 ? EnhancedTheme.errorRed : EnhancedTheme.successGreen,
                Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard(context, 'Purchases',
                '${customer.totalPurchases}',
                EnhancedTheme.accentCyan, Icons.shopping_bag_rounded)),
          ]).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.1, end: 0),

          // ── Outstanding debt warning ─────────────────────────────────────────
          if (customer.outstandingDebt > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        EnhancedTheme.errorRed.withValues(alpha: 0.12),
                        EnhancedTheme.accentOrange.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.errorRed, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Outstanding Balance',
                          style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('₦${customer.outstandingDebt.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                              color: EnhancedTheme.errorRed, fontSize: 18, fontWeight: FontWeight.w800)),
                    ])),
                    ElevatedButton(
                      onPressed: () => _showPayDebtDialog(context, ref, customer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Pay Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 120.ms),
          ],
          const SizedBox(height: 20),

          // ── Contact details ──────────────────────────────────────────────────
          _sectionTitle(context, 'Contact Details', Icons.contact_page_outlined, EnhancedTheme.infoBlue),
          const SizedBox(height: 10),
          _glassCard(context, child: Column(children: [
            _detailRow(context, Icons.phone_rounded, 'Phone', customer.phone),
            if (customer.email != null && customer.email!.isNotEmpty) ...[
              _divider(context),
              _detailRow(context, Icons.email_outlined, 'Email', customer.email!),
            ],
            if (customer.address != null && customer.address!.isNotEmpty) ...[
              _divider(context),
              _detailRow(context, Icons.location_on_outlined, 'Address', customer.address!),
            ],
            if (customer.joinDate != null) ...[
              _divider(context),
              _detailRow(context, Icons.calendar_today_outlined, 'Member Since', customer.joinDate!),
            ],
            if (customer.lastVisit != null) ...[
              _divider(context),
              _detailRow(context, Icons.access_time_rounded, 'Last Visit', customer.lastVisit!),
            ],
          ])).animate().fadeIn(duration: 400.ms, delay: 160.ms),
          const SizedBox(height: 20),

          // ── Recent purchases ─────────────────────────────────────────────────
          _sectionTitle(context, 'Purchase History', Icons.receipt_long_rounded, EnhancedTheme.accentPurple),
          const SizedBox(height: 10),
          salesAsync.when(
            loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2))),
            error: (e, _) => _glassCard(context, child: Row(children: [
              const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 18),
              const SizedBox(width: 12),
              Text('Could not load sales history',
                  style: TextStyle(color: context.subLabelColor, fontSize: 13)),
            ])),
            data: (sales) => sales.isEmpty
                ? _glassCard(context, child: Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(children: [
                      Icon(Icons.receipt_long_outlined, color: context.hintColor, size: 36),
                      const SizedBox(height: 10),
                      Text('No purchase history yet',
                          style: TextStyle(color: context.hintColor, fontSize: 13)),
                    ]),
                  )))
                : Column(children: sales.asMap().entries.map((e) =>
                    _purchaseRow(context, e.value)
                        .animate(delay: (e.key * 40).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.1, end: 0)
                  ).toList()),
          ),
          const SizedBox(height: 24),

          // ── Actions ─────────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _actionButton(
              label: 'Wallet',
              icon: Icons.account_balance_wallet_rounded,
              colors: [EnhancedTheme.successGreen, EnhancedTheme.primaryTeal],
              onTap: () => context.push('/customer/${customer.id}/wallet'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _actionButton(
              label: 'New Sale',
              icon: Icons.point_of_sale_rounded,
              colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              onTap: () => _startNewSale(context, ref, customer),
            )),
          ]).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
        ]),
      )),
    ]);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.outfit(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  // ── New sale from customer profile ─────────────────────────────────────────

  void _startNewSale(BuildContext context, WidgetRef ref, Customer customer) {
    ref.read(cartProvider.notifier).clearCart();
    ref.read(selectedCustomerProvider.notifier).state = SelectedCustomer(
      id: customer.id,
      name: customer.name,
      walletBalance: customer.walletBalance,
    );

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3), width: 1.5))),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 44, height: 5,
                        decoration: BoxDecoration(color: context.hintColor.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3)))),
                    const SizedBox(height: 20),
                    Text('Edit Customer',
                        style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
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
                    Text('Customer Type', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _typeChip(ctx, 'Retail', !isWholesale, () => setSheetState(() => isWholesale = false))),
                      const SizedBox(width: 8),
                      Expanded(child: _typeChip(ctx, 'Wholesale', isWholesale, () => setSheetState(() => isWholesale = true))),
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
                              backgroundColor: (updated != null ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.92),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              content: Row(children: [
                                Icon(updated != null ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text(updated != null ? 'Customer updated' : 'Update failed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              ]),
                            ));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Delete Customer', style: TextStyle(color: context.labelColor, fontSize: 16)),
        ]),
        content: Text(
            'Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(customerNotifierProvider.notifier).deleteCustomer(customer.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: (success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.92),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  content: Row(children: [
                    Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(success ? 'Customer deleted' : 'Delete failed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                  ]),
                ));
                if (success) { if (context.canPop()) { context.pop(); } else { context.go('/dashboard/customers'); } }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Record Debt Payment', style: TextStyle(color: context.labelColor)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.errorRed, size: 16),
                const SizedBox(width: 8),
                Text('Outstanding: ₦${customer.outstandingDebt.toStringAsFixed(2)}',
                    style: const TextStyle(color: EnhancedTheme.errorRed, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: context.labelColor),
              decoration: InputDecoration(
                hintText: 'Payment amount',
                prefixText: '₦ ',
                filled: true,
                fillColor: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Payment Method', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: ['cash', 'pos', 'transfer'].map((m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m.toUpperCase(), style: const TextStyle(fontSize: 11)),
                selected: method == m,
                onSelected: (_) => setDialogState(() => method = m),
                selectedColor: EnhancedTheme.primaryTeal,
                labelStyle: TextStyle(color: method == m ? Colors.white : context.subLabelColor, fontWeight: FontWeight.w600),
              ),
            )).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: context.hintColor))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx);
                final success = await ref.read(walletNotifierProvider(customer.id).notifier)
                    .recordPayment(amount: amount, method: method);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: (success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.92),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                    content: Row(children: [
                      Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(success ? 'Payment of ₦${amount.toStringAsFixed(2)} recorded' : 'Payment failed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    ]),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget _purchaseRow(BuildContext context, CustomerSale p) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.primaryTeal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.date,
                  style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${p.items} item${p.items == 1 ? '' : 's'}',
                  style: TextStyle(color: context.subLabelColor, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₦${p.total.toStringAsFixed(0)}',
                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w800)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(p.status,
                    style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
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
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.hintColor, fontSize: 10), textAlign: TextAlign.center),
        ]))));

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(children: [
      Icon(icon, color: context.hintColor, size: 15),
      const SizedBox(width: 10),
      SizedBox(width: 100,
          child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13))),
      Expanded(child: Text(value,
          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
    ]));

  Widget _sectionTitle(BuildContext context, String t, IconData icon, Color color) => Row(children: [
    Container(
      width: 3, height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    const SizedBox(width: 10),
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 8),
    Text(t, style: GoogleFonts.outfit(
        color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
  ]);

  Widget _divider(BuildContext context) => Divider(height: 1, color: context.dividerColor);

  Widget _chip(String label, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
      ],
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]));

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
          fillColor: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      );

  Widget _typeChip(BuildContext context, String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        gradient: selected ? const LinearGradient(
          colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ) : null,
        color: selected ? null : context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.transparent : context.borderColor,
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          label == 'Wholesale' ? Icons.store_rounded : Icons.storefront_rounded,
          color: selected ? Colors.white : context.hintColor, size: 16,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color: selected ? Colors.white : context.hintColor,
            fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    ));
}
