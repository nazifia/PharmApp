import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/cart_item.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/widgets/barcode_scanner_sheet.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/drug_interaction_provider.dart';
import '../providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'retail_cart_screen.dart';

class RetailPOSScreen extends ConsumerStatefulWidget {
  const RetailPOSScreen({super.key});

  @override
  ConsumerState<RetailPOSScreen> createState() => _RetailPOSScreenState();
}

class _RetailPOSScreenState extends ConsumerState<RetailPOSScreen> {
  final _searchCtrl = TextEditingController();
  bool _gridView = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _checkout() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }
    context.push('/payment');
  }

  Future<void> _sendToCashier() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }

    // Ask dispenser for patient/customer name before sending.
    // Controller lives entirely inside the dialog to avoid _dependents assertion.
    final patientName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.10), width: 1.5),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient top strip
                    Container(
                      height: 3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send_rounded, color: EnhancedTheme.primaryTeal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text('Send to Cashier',
                          style: GoogleFonts.outfit(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Patient / Customer name (optional)',
                        style: TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'e.g. John Doe',
                        hintStyle: const TextStyle(color: Colors.black38),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.black38, size: 18),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                          child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                        ),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // null means cancelled (tapped Cancel or dismissed dialog)
    if (patientName == null || !mounted) return;

    final items = cart.map((c) => {
      'itemId': c.item.id,
      'barcode': c.item.barcode,
      'quantity': c.quantity,
      'price': c.item.price,
      'discount': c.discount,
    }).toList();
    final customerId = ref.read(selectedCustomerProvider)?.id;
    try {
      await ref.read(posApiProvider).sendToCashier(
        items,
        customerId: customerId,
        patientName: patientName.isEmpty ? null : patientName,
      );
      if (!mounted) return;
      ref.read(cartProvider.notifier).clearCart();
      ref.read(prescriptionCartBindingsProvider.notifier).state = {};
      ref.read(selectedCustomerProvider.notifier).state = null;
      _showSnackBar('Payment request sent to cashier', type: _SnackType.success);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response == null) {
        await ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/payment-requests/',
          body: {
            'items': items,
            if (customerId != null) 'customer_id': customerId,
            'payment_type': 'retail',
            if (patientName.isNotEmpty) 'patientName': patientName,
          },
          description: 'Send payment request to cashier${patientName.isNotEmpty ? ' for $patientName' : ''}',
        );
        ref.read(cartProvider.notifier).clearCart();
        ref.read(prescriptionCartBindingsProvider.notifier).state = {};
        ref.read(selectedCustomerProvider.notifier).state = null;
        _showSnackBar('Offline — request queued for sync', type: _SnackType.warning);
      } else {
        _showSnackBar(e.response?.data?['detail']?.toString() ?? '$e', type: _SnackType.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('$e', type: _SnackType.error);
    }
  }

  void _onBarcodeScannedPOS(String code) {
    final items = ref.read(retailInventoryProvider).valueOrNull ?? [];
    final match = items.where((i) => i.barcode == code).firstOrNull;
    if (match == null) {
      _showSnackBar('Item not found for barcode: $code', type: _SnackType.error);
      return;
    }
    if (match.stock == 0) {
      _showSnackBar('${match.name} is out of stock', type: _SnackType.error);
      return;
    }
    final cart = ref.read(cartProvider);
    final inCart = cart.where((c) => c.item.id == match.id).fold<int>(0, (s, c) => s + c.quantity);
    if (inCart >= match.stock) {
      _showSnackBar('${match.name} — maximum stock in cart', type: _SnackType.error);
      return;
    }
    ref.read(cartProvider.notifier).addItem(match);
    _showSnackBar('${match.name} added to cart', type: _SnackType.success);
  }

  void _showSnackBar(String msg, {required _SnackType type}) {
    final color = type == _SnackType.success
        ? EnhancedTheme.successGreen
        : type == _SnackType.error
            ? EnhancedTheme.errorRed
            : type == _SnackType.warning
                ? EnhancedTheme.warningAmber
                : EnhancedTheme.infoBlue;
    final icon = type == _SnackType.success
        ? Icons.check_circle_rounded
        : type == _SnackType.error
            ? Icons.error_rounded
            : type == _SnackType.warning
                ? Icons.cloud_off_rounded
                : Icons.info_rounded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(icon, color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  // ── Branch picker modal ───────────────────────────────────────────────────

  void _showBranchPicker(BuildContext context) {
    final user = ref.read(currentUserProvider);
    // Users with a backend-assigned branch are locked — cannot switch.
    if ((user?.branchId ?? 0) != 0) return;

    final branches = ref.read(branchListProvider);
    final active   = branches.where((b) => b.isActive).toList();
    final userRole = user?.role ?? '';
    final isAdmin  = const {'Admin', 'Manager', 'Wholesale Manager'}.contains(userRole);
    final current  = ref.read(activeBranchProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store_rounded, color: EnhancedTheme.primaryTeal, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Select Branch',
                  style: GoogleFonts.outfit(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            if (isAdmin) _branchPickerTile(
              ctx: ctx,
              icon: Icons.business_rounded,
              label: 'All Branches',
              subtitle: 'Show items across all branches',
              isSelected: current == null || current.id <= 0,
              onTap: () {
                ref.read(activeBranchProvider.notifier).state = null;
                ref.invalidate(retailInventoryProvider);
                Navigator.pop(ctx);
              },
            ),
            if (isAdmin && active.isNotEmpty) const Divider(color: Colors.black12, height: 16),
            ...active.map((b) => _branchPickerTile(
              ctx: ctx,
              icon: b.isMain ? Icons.home_work_rounded : Icons.store_outlined,
              label: b.name,
              subtitle: b.address.isNotEmpty ? b.address : null,
              badge: b.isMain ? 'Main' : null,
              isSelected: current?.id == b.id,
              onTap: () {
                ref.read(activeBranchProvider.notifier).state = b;
                ref.invalidate(retailInventoryProvider);
                Navigator.pop(ctx);
              },
            )),
            if (active.isEmpty && !isAdmin)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No branches available.', style: TextStyle(color: Colors.black45, fontSize: 13)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _branchPickerTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    String? subtitle,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? EnhancedTheme.primaryTeal.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4) : Colors.black12,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Icon(icon, color: isSelected ? EnhancedTheme.primaryTeal : Colors.black45, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: isSelected ? EnhancedTheme.primaryTeal : Colors.black87,
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge,
                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: EnhancedTheme.primaryTeal, size: 18),
      ]),
    ),
  );

  // ── Customer picker modal ─────────────────────────────────────────────────

  void _showCustomerPicker(List customers) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (ctx, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setSheetState) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: ctx.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.97) : Colors.white.withValues(alpha: 0.97),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: ctx.borderColor),
                ),
                child: Column(children: [
                  // Gradient handle strip
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.people_rounded, color: EnhancedTheme.primaryTeal, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text('Select Customer',
                          style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(selectedCustomerProvider.notifier).state = null;
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.clear_rounded, size: 14, color: EnhancedTheme.errorRed),
                        label: const Text('Clear', style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 13)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      style: TextStyle(color: ctx.labelColor),
                      decoration: InputDecoration(
                        hintText: 'Search customers…',
                        hintStyle: TextStyle(color: ctx.hintColor),
                        prefixIcon: Icon(Icons.search_rounded, color: ctx.hintColor, size: 20),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, color: ctx.hintColor, size: 16),
                                onPressed: () { searchCtrl.clear(); setSheetState(() {}); })
                            : null,
                        filled: true, fillColor: ctx.cardColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: Builder(builder: (_) {
                    final q = searchCtrl.text.toLowerCase();
                    final filtered = customers.where((c) =>
                        c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
                    if (filtered.isEmpty) {
                      return Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                                EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                              ]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.people_outline_rounded, color: EnhancedTheme.primaryTeal, size: 32),
                          ),
                          const SizedBox(height: 12),
                          Text('No customers found',
                              style: GoogleFonts.inter(color: ctx.subLabelColor, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Try a different name or phone number',
                              style: TextStyle(color: ctx.hintColor, fontSize: 12)),
                        ],
                      ));
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final isSelected = ref.read(selectedCustomerProvider)?.id == c.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4)
                                  : ctx.borderColor,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              tileColor: isSelected
                                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.1)
                                  : ctx.cardColor,
                              onTap: () {
                                ref.read(selectedCustomerProvider.notifier).state = SelectedCustomer(
                                  id: c.id, name: c.name, walletBalance: c.walletBalance);
                                Navigator.pop(ctx);
                              },
                              leading: CircleAvatar(
                                backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.outfit(
                                      color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700)),
                              ),
                              title: Text(c.name,
                                  style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                              isThreeLine: c.walletBalance > 0,
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.phone, style: TextStyle(color: ctx.subLabelColor, fontSize: 12)),
                                if (c.walletBalance > 0)
                                  Text('Wallet: ₦${c.walletBalance.toStringAsFixed(0)}',
                                      style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                              trailing: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded, color: EnhancedTheme.primaryTeal, size: 14))
                                  : null,
                            ),
                          ),
                        );
                      },
                    );
                  })),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(retailInventoryProvider);
    final customersAsync = ref.watch(customerListProvider);
    final cart           = ref.watch(cartProvider);
    final cartTotal      = cart.fold(0.0, (sum, c) => sum + c.total);
    final cartCount      = cart.fold<int>(0, (s, c) => s + c.quantity);
    final wide           = MediaQuery.of(context).size.width > 800;

    final filteredAsync = inventoryAsync.whenData((items) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isEmpty) return items;
      return items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.brand.toLowerCase().contains(q) ||
          i.barcode.toLowerCase().contains(q)).toList();
    });

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context, cartCount),
          _customerRow(context, customersAsync),
          Expanded(child: wide
              ? Row(children: [
                  Expanded(flex: 3, child: _itemsPanel(filteredAsync, cart)),
                  VerticalDivider(width: 1, color: context.borderColor),
                  Expanded(flex: 2, child: _cartPanel(cart, cartTotal)),
                ])
              : _mobileLayout(filteredAsync, cart, cartTotal)),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, int cartCount) {
    final itemCount = ref.watch(retailInventoryProvider).whenOrNull(data: (l) => l.length);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
            EnhancedTheme.accentCyan.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Builder(builder: (ctx) => GestureDetector(
          onTap: () => ctx.canPop()
              ? ctx.pop()
              : Scaffold.of(ctx).openDrawer(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              ctx.canPop() ? Icons.arrow_back_rounded : Icons.menu_rounded,
              color: Colors.black, size: 18),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Retail POS',
              style: GoogleFonts.outfit(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
          Row(children: [
            Flexible(child: Builder(builder: (_) {
              final activeBranch = ref.watch(activeBranchProvider);
              final label = (activeBranch != null && activeBranch.id > 0)
                  ? activeBranch.name
                  : 'All Branches';
              final isSpecific = activeBranch != null && activeBranch.id > 0;
              return GestureDetector(
                onTap: () => _showBranchPicker(context),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSpecific
                        ? EnhancedTheme.primaryTeal.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSpecific
                          ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4)
                          : Colors.black26,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isSpecific ? Icons.store_rounded : Icons.business_rounded,
                      color: isSpecific ? EnhancedTheme.primaryTeal : Colors.black54,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Flexible(child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isSpecific ? EnhancedTheme.primaryTeal : Colors.black54,
                            fontSize: 10, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 2),
                    Icon(Icons.expand_more_rounded,
                        color: isSpecific ? EnhancedTheme.primaryTeal : Colors.black54,
                        size: 10),
                  ]),
                ),
                ),
              );
            })),
            if (itemCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$itemCount items',
                    style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ])),
        // Grid / List toggle
        GestureDetector(
          onTap: () => setState(() => _gridView = !_gridView),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Colors.black, size: 18,
            ),
          ),
        ),
        if (cartCount > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_rounded, color: Colors.black, size: 13),
              const SizedBox(width: 4),
              Text('$cartCount',
                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }

  // ── Customer Row ───────────────────────────────────────────────────────────

  Widget _customerRow(BuildContext context, AsyncValue customersAsync) {
    final selected = ref.watch(selectedCustomerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GestureDetector(
        onTap: () {
          final customers = customersAsync.valueOrNull ?? [];
          _showCustomerPicker(customers);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected != null
                ? EnhancedTheme.primaryTeal.withValues(alpha: 0.1)
                : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected != null
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4)
                  : context.borderColor,
              width: selected != null ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (selected != null ? EnhancedTheme.primaryTeal : context.hintColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.person_rounded,
                  color: selected != null ? EnhancedTheme.primaryTeal : context.hintColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: selected != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(selected.name,
                        style: TextStyle(color: context.labelColor,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: EnhancedTheme.successGreen, size: 11),
                      const SizedBox(width: 4),
                      Text('₦${selected.walletBalance.toStringAsFixed(0)}',
                          style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ])
                : Text('Link a customer (optional)',
                    style: TextStyle(color: context.hintColor, fontSize: 13))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: selected != null ? EnhancedTheme.primaryTeal : context.hintColor, size: 20),
          ]),
        ),
      ),
    );
  }

  // ── Mobile layout (tabs) ───────────────────────────────────────────────────

  Widget _mobileLayout(AsyncValue<List<Item>> filtered, List<CartItem> cart, double cartTotal) {
    final count = filtered.whenOrNull(data: (l) => l.length) ?? 0;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            border: Border(bottom: BorderSide(color: context.borderColor)),
          ),
          child: TabBar(
            labelColor: EnhancedTheme.primaryTeal,
            unselectedLabelColor: context.hintColor,
            indicatorColor: EnhancedTheme.primaryTeal,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'Catalogue ($count)'),
              Tab(text: 'Cart (${cart.length})'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _itemsPanel(filtered, cart),
          _cartPanel(cart, cartTotal),
        ])),
      ]),
    );
  }

  // ── Items Panel ────────────────────────────────────────────────────────────

  Widget _itemsPanel(AsyncValue<List<Item>> filtered, List<CartItem> cart) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: context.labelColor),
              decoration: InputDecoration(
                hintText: 'Search items by name, brand, barcode…',
                hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: context.hintColor, size: 16),
                        onPressed: () => setState(() => _searchCtrl.clear()))
                    : null,
                filled: true, fillColor: context.cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showBarcodeScannerSheet(context, _onBarcodeScannedPOS),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: EnhancedTheme.primaryTeal, size: 22),
            ),
          ),
        ]),
      ),
      Expanded(child: filtered.when(
        loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Loading catalogue…', style: TextStyle(color: context.hintColor, fontSize: 13)),
        ])),
        error: (e, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Failed to load items', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(retailInventoryProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: EnhancedTheme.primaryTeal),
              label: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: EnhancedTheme.primaryTeal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        )),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, color: EnhancedTheme.primaryTeal, size: 40),
              ),
              const SizedBox(height: 16),
              Text('No items found', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_searchCtrl.text.isEmpty ? 'Add items from the inventory module' : 'Try a different search term',
                  style: TextStyle(color: context.subLabelColor, fontSize: 13)),
            ]));
          }
          return _gridView
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueGridCard(items[i], cart)
                      .animate(delay: (i * 30).ms)
                      .fadeIn(duration: 250.ms)
                      .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueListItem(items[i], cart)
                      .animate(delay: (i * 25).ms)
                      .fadeIn(duration: 250.ms)
                      .slideX(begin: 0.05, end: 0),
                );
        },
      )),
    ]);
  }

  Color _categoryColor(Item item) {
    // Derive accent color from item name keywords
    final name = item.name.toLowerCase();
    if (name.contains('pain') || name.contains('analg') || name.contains('ibuprofen') || name.contains('aspirin')) {
      return EnhancedTheme.errorRed;
    }
    if (name.contains('antibiotic') || name.contains('amoxicil') || name.contains('cipro')) {
      return EnhancedTheme.accentPurple;
    }
    if (name.contains('vitamin') || name.contains('supplement') || name.contains('zinc')) {
      return EnhancedTheme.successGreen;
    }
    if (name.contains('antiviral') || name.contains('acyclo')) {
      return EnhancedTheme.infoBlue;
    }
    return EnhancedTheme.primaryTeal;
  }

  Widget _catalogueListItem(Item item, List<CartItem> cart) {
    final cartItem   = cart.where((c) => c.item.id == item.id).firstOrNull;
    final inCart     = cartItem?.quantity ?? 0;
    final outOfStock = item.stock == 0;
    final lowStock   = item.stock > 0 && item.stock <= 5;
    final atStockCap = inCart >= item.stock;
    final accentColor = outOfStock ? context.hintColor : _categoryColor(item);

    final wide = MediaQuery.of(context).size.width > 800;

    void onCardTap() {
      if (outOfStock || atStockCap) return;
      ref.read(cartProvider.notifier).addItem(item);
      if (!wide) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailCartScreen()));
      }
    }

    return GestureDetector(
      onTap: onCardTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart > 0
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.07)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: inCart > 0
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.35)
                    : context.borderColor,
                width: inCart > 0 ? 1.5 : 1.0,
              ),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: outOfStock ? 0.08 : 0.18),
                      accentColor.withValues(alpha: outOfStock ? 0.04 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.medication_rounded, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name,
                    style: TextStyle(
                        color: outOfStock ? context.hintColor : context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (item.brand.isNotEmpty)
                  Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: outOfStock
                        ? EnhancedTheme.errorRed.withValues(alpha: 0.12)
                        : lowStock
                            ? EnhancedTheme.warningAmber.withValues(alpha: 0.12)
                            : EnhancedTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    outOfStock ? 'Out of stock' : lowStock ? '${item.stock} left — low' : '${item.stock} in stock',
                    style: TextStyle(
                      color: outOfStock
                          ? EnhancedTheme.errorRed
                          : lowStock
                              ? EnhancedTheme.warningAmber
                              : EnhancedTheme.successGreen,
                      fontSize: 10, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('₦', style: TextStyle(
                    color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
                    fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(item.price.toStringAsFixed(0),
                      style: TextStyle(
                        color: outOfStock ? context.hintColor : EnhancedTheme.primaryTeal,
                        fontSize: 15, fontWeight: FontWeight.w800,
                      )),
                ]),
                const SizedBox(height: 6),
                if (inCart > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: atStockCap
                          ? null
                          : const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                      color: atStockCap ? EnhancedTheme.warningAmber.withValues(alpha: 0.12) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      atStockCap ? 'Max ($inCart)' : '×$inCart in cart',
                      style: TextStyle(
                        color: atStockCap ? EnhancedTheme.warningAmber : Colors.black,
                        fontSize: 10, fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (!outOfStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Tap to add',
                        style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _catalogueGridCard(Item item, List<CartItem> cart) {
    final cartItem   = cart.where((c) => c.item.id == item.id).firstOrNull;
    final inCart     = cartItem?.quantity ?? 0;
    final outOfStock = item.stock == 0;
    final lowStock   = item.stock > 0 && item.stock <= 5;
    final atStockCap = inCart >= item.stock;
    final accentColor = outOfStock ? context.hintColor : _categoryColor(item);

    return GestureDetector(
      onTap: (outOfStock || atStockCap)
          ? null
          : () {
              ref.read(cartProvider.notifier).addItem(item);
              final wide = MediaQuery.of(context).size.width > 800;
              if (!wide) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailCartScreen()));
              }
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart > 0
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.08)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: inCart > 0
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.45)
                    : context.borderColor,
                width: inCart > 0 ? 1.5 : 1.0,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: outOfStock ? 0.08 : 0.2),
                        accentColor.withValues(alpha: outOfStock ? 0.04 : 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.medication_rounded, color: accentColor, size: 18),
                ),
                if (inCart > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$inCart',
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const Spacer(),
              Text(item.name,
                  style: TextStyle(
                    color: outOfStock ? context.hintColor : context.labelColor,
                    fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('₦${item.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: outOfStock ? context.hintColor : EnhancedTheme.primaryTeal,
                    fontSize: 14, fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: outOfStock
                      ? EnhancedTheme.errorRed.withValues(alpha: 0.1)
                      : lowStock
                          ? EnhancedTheme.warningAmber.withValues(alpha: 0.1)
                          : atStockCap
                              ? EnhancedTheme.warningAmber.withValues(alpha: 0.1)
                              : EnhancedTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  outOfStock ? 'Out of stock' : atStockCap ? 'Max in cart' : lowStock ? '${item.stock} left' : '${item.stock} left',
                  style: TextStyle(
                    color: outOfStock
                        ? EnhancedTheme.errorRed
                        : (atStockCap || lowStock)
                            ? EnhancedTheme.warningAmber
                            : EnhancedTheme.successGreen,
                    fontSize: 9, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Drug interaction helpers ───────────────────────────────────────────────

  Color _warningSeverityColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'allergy':
      case 'major':
      case 'high':
        return EnhancedTheme.errorRed;
      case 'low':
      case 'minor':
        return EnhancedTheme.infoBlue;
      default:
        return EnhancedTheme.warningAmber;
    }
  }

  void _showInteractionDialog(List<PosWarning> warnings) {
    // Group by source for a cleaner dialog layout
    final patientWarns =
        warnings.where((w) => w.source == 'Patient Profile').toList();
    final rxNormWarns =
        warnings.where((w) => w.source != 'Patient Profile').toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_rounded,
                color: EnhancedTheme.warningAmber, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Drug Warnings',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (patientWarns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _dialogSection('Patient Profile', patientWarns),
                ],
                if (rxNormWarns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _dialogSection('Drug-Drug Interactions', rxNormWarns),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood',
                style: TextStyle(
                    color: EnhancedTheme.primaryTeal,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _dialogSection(String heading, List<PosWarning> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(heading,
            style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ),
      const SizedBox(height: 8),
      ...items.asMap().entries.map((e) {
        final i = e.key;
        final w = e.value;
        final color = _warningSeverityColor(w.severity);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i > 0) const Divider(color: Colors.black12, height: 16),
          Row(children: [
            Expanded(
              child: Text(w.title,
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(w.severity.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          if (w.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(w.description,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 11)),
          ],
          if (w.source.isNotEmpty && w.source != 'Patient Profile') ...[
            const SizedBox(height: 3),
            Text('Source: ${w.source}',
                style: const TextStyle(
                    color: Colors.black38, fontSize: 10)),
          ],
        ]);
      }),
    ]);
  }

  Widget _interactionBanner(AsyncValue<List<PosWarning>> warningsAsync) {
    return warningsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: EnhancedTheme.primaryTeal),
          ),
          const SizedBox(width: 8),
          Text('Checking drug interactions…',
              style: TextStyle(color: context.subLabelColor, fontSize: 11)),
        ]),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (warnings) {
        if (warnings.isEmpty) return const SizedBox.shrink();
        final hasAllergy = warnings
            .any((w) => w.severity.toLowerCase() == 'allergy');
        final hasHigh = warnings
            .any((w) => ['high', 'major'].contains(w.severity.toLowerCase()));
        final color = (hasAllergy || hasHigh)
            ? EnhancedTheme.errorRed
            : EnhancedTheme.warningAmber;
        final label = hasAllergy
            ? '${warnings.length} allergy/interaction warning'
                '${warnings.length > 1 ? 's' : ''} — tap to review'
            : '${warnings.length} drug warning'
                '${warnings.length > 1 ? 's' : ''} detected — tap to review';
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: GestureDetector(
            onTap: () => _showInteractionDialog(warnings),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: color.withValues(alpha: 0.40)),
              ),
              child: Row(children: [
                Icon(
                  hasAllergy
                      ? Icons.emergency_rounded
                      : Icons.warning_rounded,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 16),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── Cart Panel (wide layout) ───────────────────────────────────────────────

  Widget _cartPanel(List<CartItem> cart, double cartTotal) {
    final interactionsAsync = ref.watch(combinedPosWarningsProvider);
    return Column(children: [
      Expanded(child: cart.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.06),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined, color: context.hintColor, size: 28),
              ),
              const SizedBox(height: 10),
              Text('Cart is empty', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Tap any item to add', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: cart.length,
              itemBuilder: (_, i) => _RetailCartItem(
                key: ValueKey(cart[i].item.id),
                item: cart[i],
              ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0),
            )),

      _interactionBanner(interactionsAsync),
      if (cart.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailCartScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ── Cart item row ─────────────────────────────────────────────────────────────

class _RetailCartItem extends ConsumerStatefulWidget {
  final CartItem item;
  const _RetailCartItem({required this.item, super.key});

  @override
  ConsumerState<_RetailCartItem> createState() => _RetailCartItemState();
}

class _RetailCartItemState extends ConsumerState<_RetailCartItem> {
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(
        text: widget.item.discount > 0 ? widget.item.discount.toStringAsFixed(0) : '');
  }

  @override
  void didUpdateWidget(_RetailCartItem old) {
    super.didUpdateWidget(old);
    if (old.item.discount != widget.item.discount) {
      final parsed = double.tryParse(_discountCtrl.text) ?? 0;
      if (parsed != widget.item.discount) {
        _discountCtrl.text = widget.item.discount > 0
            ? widget.item.discount.toStringAsFixed(0)
            : '';
      }
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.item;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: [
            Row(children: [
              // Colored left accent strip
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.item.name,
                    style: TextStyle(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                RichText(text: TextSpan(
                  style: TextStyle(color: context.subLabelColor, fontSize: 11),
                  children: [
                    TextSpan(text: '₦${c.item.price.toStringAsFixed(0)}'),
                    const TextSpan(text: ' × '),
                    TextSpan(text: '${c.quantity}',
                        style: const TextStyle(color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' = '),
                    TextSpan(text: '₦${c.total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                )),
              ])),
              const SizedBox(width: 8),
              // Colored quantity controls
              Row(children: [
                _qtyBtn(Icons.remove_rounded,
                    () => ref.read(cartProvider.notifier).updateQuantity(c.item.id, c.quantity - 1),
                    color: EnhancedTheme.errorRed),
                _QtyField(
                  quantity: c.quantity,
                  maxStock: c.item.stock,
                  onChanged: (n) => ref.read(cartProvider.notifier).updateQuantity(c.item.id, n),
                ),
                _qtyBtn(Icons.add_rounded,
                    () => ref.read(cartProvider.notifier).updateQuantity(c.item.id, c.quantity + 1),
                    color: EnhancedTheme.successGreen),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.discount_rounded, color: EnhancedTheme.warningAmber, size: 12),
              ),
              const SizedBox(width: 6),
              Text('Discount:', style: TextStyle(color: context.hintColor, fontSize: 11)),
              const SizedBox(width: 6),
              SizedBox(
                width: 76,
                height: 28,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.labelColor, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    hintText: '0',
                    hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
                    prefixText: '₦',
                    prefixStyle: TextStyle(color: context.hintColor, fontSize: 11),
                    filled: true, fillColor: context.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(7)),
                        borderSide: BorderSide(color: EnhancedTheme.warningAmber, width: 1.5)),
                  ),
                  onChanged: (v) {
                    final d = double.tryParse(v) ?? 0;
                    ref.read(cartProvider.notifier).updateDiscount(c.item.id, d);
                  },
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(cartProvider.notifier).removeItem(c.item.id),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.close_rounded, color: EnhancedTheme.errorRed, size: 14),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {required Color color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 15),
    ),
  );
}

// ── Editable quantity field ───────────────────────────────────────────────────

class _QtyField extends StatefulWidget {
  final int quantity;
  final int maxStock;
  final ValueChanged<int> onChanged;
  const _QtyField({required this.quantity, required this.maxStock, required this.onChanged});

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void didUpdateWidget(_QtyField old) {
    super.didUpdateWidget(old);
    if (old.quantity != widget.quantity) {
      final parsed = int.tryParse(_ctrl.text);
      if (parsed != widget.quantity) {
        _ctrl.text = '${widget.quantity}';
        _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _ctrl.text.length));
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 30,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700),
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n >= 1) {
            widget.onChanged(n.clamp(1, widget.maxStock));
          }
        },
        onSubmitted: (v) {
          final n = int.tryParse(v) ?? widget.quantity;
          final clamped = n.clamp(1, widget.maxStock);
          widget.onChanged(clamped);
          _ctrl.text = '$clamped';
        },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Snack type helper ─────────────────────────────────────────────────────────
enum _SnackType { success, error, warning }
