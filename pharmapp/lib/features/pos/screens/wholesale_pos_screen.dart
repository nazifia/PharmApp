import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/models/sale.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

const _kWalkInId = -1;
const _kWalkInName = 'Walk-in Customer';

// ─────────────────────────────────────────────────────────────────────────────

class WholesalePOSScreen extends ConsumerStatefulWidget {
  const WholesalePOSScreen({super.key});

  @override
  ConsumerState<WholesalePOSScreen> createState() => _WholesalePOSScreenState();
}

class _WholesalePOSScreenState extends ConsumerState<WholesalePOSScreen> {
  final _searchCtrl = TextEditingController();
  int?   _selectedCustomerId;
  String? _selectedCustomerName;
  double  _selectedCustomerWallet = 0;
  bool    _gridView = false;
  final List<_CartLine> _cart = [];
  bool _isSubmitting = false;

  double get _cartTotal => _cart.fold(0.0, (s, l) => s + l.total);
  int    get _cartCount => _cart.fold(0, (s, l) => s + l.qty);

  @override
  void initState() {
    super.initState();
    // Pre-select customer if navigated here from the customer profile "New Sale" button.
    // Read synchronously so the first build already has the customer — no flicker.
    final pre = ref.read(selectedCustomerProvider);
    if (pre != null) {
      _selectedCustomerId     = pre.id;
      _selectedCustomerName   = pre.name;
      _selectedCustomerWallet = pre.walletBalance;
      // Clear after the first frame so the provider doesn't bleed into future sessions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(selectedCustomerProvider.notifier).state = null;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {required _SnackType type}) {
    final color = type == _SnackType.success
        ? EnhancedTheme.successGreen
        : type == _SnackType.error
            ? EnhancedTheme.errorRed
            : EnhancedTheme.warningAmber;
    final icon = type == _SnackType.success
        ? Icons.check_circle_rounded
        : type == _SnackType.error
            ? Icons.error_rounded
            : Icons.warning_amber_rounded;
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

  // ── Cart ops ───────────────────────────────────────────────────────────────

  void _addToCart(Item item) {
    if (item.stock == 0) return;
    final idx = _cart.indexWhere((l) => l.id == item.id);
    setState(() {
      if (idx >= 0) {
        if (_cart[idx].qty >= _cart[idx].stock) return; // stock cap
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + 1);
      } else {
        _cart.add(_CartLine(
          id: item.id, name: item.name,
          price: item.price, qty: 1, barcode: item.barcode,
          stock: item.stock,
        ));
      }
    });
  }

  void _removeFromCart(int id) =>
      setState(() => _cart.removeWhere((l) => l.id == id));

  void _updateQty(int id, int qty) {
    if (qty <= 0) { _removeFromCart(id); return; }
    setState(() {
      final idx = _cart.indexWhere((l) => l.id == id);
      if (idx >= 0) _cart[idx] = _cart[idx].copyWith(qty: qty.clamp(1, _cart[idx].stock));
    });
  }

  void _updateDiscount(int id, double discount) {
    setState(() {
      final idx = _cart.indexWhere((l) => l.id == id);
      if (idx >= 0) {
        final max = _cart[idx].price * _cart[idx].qty;
        _cart[idx] = _cart[idx].copyWith(discount: discount.clamp(0, max));
      }
    });
  }

  // ── Customer picker modal ─────────────────────────────────────────────────

  void _showCustomerPicker(List<Customer> customers) {
    final searchCtrl = TextEditingController();
    final wsCustomers = customers.where((c) => c.isWholesale).toList();

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
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
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
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text('Select Customer',
                          style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedCustomerId = null;
                            _selectedCustomerName = null;
                            _selectedCustomerWallet = 0;
                          });
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
                        hintText: 'Search by name or phone…',
                        hintStyle: TextStyle(color: ctx.hintColor),
                        prefixIcon: Icon(Icons.search_rounded, color: ctx.hintColor, size: 20),
                        filled: true, fillColor: ctx.cardColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Walk-in customer shortcut
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedCustomerId == _kWalkInId
                            ? EnhancedTheme.accentOrange.withValues(alpha: 0.1)
                            : ctx.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedCustomerId == _kWalkInId
                              ? EnhancedTheme.accentOrange.withValues(alpha: 0.4)
                              : ctx.borderColor,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = _kWalkInId;
                            _selectedCustomerName = _kWalkInName;
                            _selectedCustomerWallet = 0;
                          });
                          Navigator.pop(ctx);
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.accentOrange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline_rounded, color: EnhancedTheme.accentOrange, size: 18),
                        ),
                        title: Text(_kWalkInName,
                            style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('No account required',
                            style: TextStyle(color: ctx.hintColor, fontSize: 12)),
                        trailing: _selectedCustomerId == _kWalkInId
                            ? Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: EnhancedTheme.accentOrange.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, color: EnhancedTheme.accentOrange, size: 14))
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: Builder(builder: (_) {
                    final q = searchCtrl.text.toLowerCase();
                    final filtered = wsCustomers.where((c) =>
                        c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
                    if (filtered.isEmpty) {
                      return Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                                EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                              ]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.people_outline_rounded, color: EnhancedTheme.accentCyan, size: 32),
                          ),
                          const SizedBox(height: 12),
                          Text('No wholesale customers found',
                              style: GoogleFonts.inter(color: ctx.subLabelColor, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Try a different search term',
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
                        final isSelected = _selectedCustomerId == c.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? EnhancedTheme.accentCyan.withValues(alpha: 0.1)
                                : ctx.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                                  : ctx.borderColor,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _selectedCustomerId = c.id;
                                _selectedCustomerName = c.name;
                                _selectedCustomerWallet = c.walletBalance;
                              });
                              Navigator.pop(ctx);
                            },
                            leading: CircleAvatar(
                              backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: GoogleFonts.outfit(
                                    color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(c.name,
                                style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.phone,
                                  style: TextStyle(color: ctx.subLabelColor, fontSize: 12)),
                              if (c.walletBalance > 0)
                                Text('Wallet: ₦${c.walletBalance.toStringAsFixed(0)}',
                                    style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                              if (c.outstandingDebt > 0)
                                Text('Debt: ₦${c.outstandingDebt.toStringAsFixed(0)}',
                                    style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: EnhancedTheme.accentCyan, size: 14))
                                : null,
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

  // ── Payment method sheet ──────────────────────────────────────────────────

  void _showPaymentSheet() {
    if (_cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }
    if (_selectedCustomerName == null) {
      _showSnackBar('Please select a customer or choose Walk-in', type: _SnackType.warning);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        total: _cartTotal,
        walletBalance: _selectedCustomerWallet,
        customerName: _selectedCustomerName ?? '',
        onConfirm: (method, payments) => _processCheckout(method, payments),
      ),
    );
  }

  Future<void> _processCheckout(String method, Map<String, double> payments) async {
    setState(() => _isSubmitting = true);
    try {
      final payload = CheckoutPayload(
        items: _cart.map((l) => SaleItemPayload(
          barcode: l.barcode,
          itemId: l.id,
          quantity: l.qty,
          price: l.price,
          discount: l.discount,
        )).toList(),
        payment: PaymentPayload(
          cash: payments['cash'] ?? 0,
          pos: payments['pos'] ?? 0,
          bankTransfer: payments['bankTransfer'] ?? 0,
          wallet: payments['wallet'] ?? 0,
        ),
        customerId: (_selectedCustomerId == _kWalkInId) ? null : _selectedCustomerId,
        totalAmount: _cartTotal,
        isWholesale: true,
        paymentMethod: method,
      );
      final result = await ref.read(posApiProvider).submitCheckout(payload);
      if (!mounted) return;

      final total = _cartTotal;
      final name  = _selectedCustomerName ?? 'Customer';

      setState(() {
        _cart.clear();
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _selectedCustomerWallet = 0;
      });

      if (result['offline'] == true) {
        // Queued while offline
        _showSnackBar('No connection — sale saved and will sync when online', type: _SnackType.warning);
      } else {
        final receiptId = result['receiptId'] as String? ?? result['receipt_id'] as String? ?? '';
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _WholesaleSuccessSheet(
            total: total,
            customerName: name,
            receiptId: receiptId,
            paymentMethod: method,
            onDone: () {
              Navigator.pop(context);
              _searchCtrl.clear();
              setState(() {});
            },
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data is Map && e.response!.data['detail'] != null
              ? e.response!.data['detail'].toString()
              : 'Checkout failed (${e.response?.statusCode ?? e.message})')
          : 'Checkout failed: $e';
      _showSnackBar(msg, type: _SnackType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Send to cashier ────────────────────────────────────────────────────────

  Future<void> _sendToCashier() async {
    if (_cart.isEmpty) {
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
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send_rounded, color: EnhancedTheme.accentCyan, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text('Send to Cashier',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Patient / Customer name (optional)',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. John Doe',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: EnhancedTheme.accentCyan, width: 1.5),
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
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
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
                          child: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

    // null means cancelled
    if (patientName == null || !mounted) return;

    final items = _cart.map((l) => {
      'itemId': l.id,
      'barcode': l.barcode,
      'quantity': l.qty,
      'price': l.price,
      'discount': l.discount,
    }).toList();
    final effectiveCustomerId =
        (_selectedCustomerId == _kWalkInId) ? null : _selectedCustomerId;
    try {
      await ref.read(posApiProvider).sendToCashier(
        items,
        customerId: effectiveCustomerId,
        paymentType: 'wholesale',
        patientName: patientName.isEmpty ? null : patientName,
      );
      if (!mounted) return;
      _showSnackBar('Payment request sent to cashier', type: _SnackType.success);
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data is Map && e.response!.data['detail'] != null
              ? e.response!.data['detail'].toString()
              : 'Request failed (${e.response?.statusCode ?? e.message})')
          : '$e';
      _showSnackBar(msg, type: _SnackType.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final customersAsync = ref.watch(customerListProvider);
    final wide = MediaQuery.of(context).size.width > 800;

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
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context),
          _customerRow(context, customersAsync),
          Expanded(child: wide
              ? Row(children: [
                  Expanded(flex: 3, child: _itemsPanel(filteredAsync)),
                  VerticalDivider(width: 1, color: context.borderColor),
                  Expanded(flex: 2, child: _cartPanel()),
                ])
              : _mobileLayout(filteredAsync)),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    final itemCount = ref.watch(inventoryListProvider).whenOrNull(data: (l) => l.length);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EnhancedTheme.accentCyan.withValues(alpha: 0.2),
            EnhancedTheme.accentPurple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wholesale POS',
              style: GoogleFonts.outfit(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
          Row(children: [
            Text('Bulk order processing',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
            if (itemCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$itemCount items',
                    style: const TextStyle(color: EnhancedTheme.accentPurple, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ])),
        // Grid/List toggle
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
        if (_cartCount > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: EnhancedTheme.accentCyan.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_rounded, color: Colors.black, size: 13),
              const SizedBox(width: 4),
              Text('$_cartCount',
                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }

  // ── Customer Row ────────────────────────────────────────────────────────────

  Widget _customerRow(BuildContext context, AsyncValue<List<Customer>> customersAsync) {
    final hasCustomer = _selectedCustomerId != null;
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
            color: hasCustomer
                ? EnhancedTheme.accentCyan.withValues(alpha: 0.1)
                : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasCustomer
                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                  : context.borderColor,
              width: hasCustomer ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (hasCustomer ? EnhancedTheme.accentCyan : context.hintColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.store_rounded,
                  color: hasCustomer ? EnhancedTheme.accentCyan : context.hintColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: hasCustomer
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selectedCustomerName!,
                        style: TextStyle(color: context.labelColor,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: EnhancedTheme.successGreen, size: 11),
                      const SizedBox(width: 4),
                      Text('₦${_selectedCustomerWallet.toStringAsFixed(0)}',
                          style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ])
                : Text('Select wholesale customer',
                    style: TextStyle(color: context.hintColor, fontSize: 13))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: hasCustomer ? EnhancedTheme.accentCyan : context.hintColor, size: 20),
          ]),
        ),
      ),
    );
  }

  // ── Mobile layout (tabbed) ─────────────────────────────────────────────────

  Widget _mobileLayout(AsyncValue<List<Item>> filtered) {
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
            labelColor: EnhancedTheme.accentCyan,
            unselectedLabelColor: context.hintColor,
            indicatorColor: EnhancedTheme.accentCyan,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'Catalogue ($count)'),
              Tab(text: 'Cart (${_cart.length})'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _itemsPanel(filtered),
          _cartPanel(),
        ])),
      ]),
    );
  }

  // ── Items Panel ────────────────────────────────────────────────────────────

  Widget _itemsPanel(AsyncValue<List<Item>> filtered) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
      Expanded(child: filtered.when(
        loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: EnhancedTheme.accentCyan, strokeWidth: 2.5),
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
              onPressed: () => ref.invalidate(inventoryListProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: EnhancedTheme.accentCyan),
              label: const Text('Retry', style: TextStyle(color: EnhancedTheme.accentCyan)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: EnhancedTheme.accentCyan),
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
                    EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    EnhancedTheme.accentPurple.withValues(alpha: 0.08),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, color: EnhancedTheme.accentCyan, size: 40),
              ),
              const SizedBox(height: 16),
              Text('No items found', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_searchCtrl.text.isEmpty ? 'Add wholesale items from inventory' : 'Try a different search term',
                  style: TextStyle(color: context.subLabelColor, fontSize: 13)),
            ]));
          }
          return _gridView
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueGridCard(items[i])
                      .animate(delay: (i * 30).ms)
                      .fadeIn(duration: 250.ms)
                      .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueListItem(items[i])
                      .animate(delay: (i * 25).ms)
                      .fadeIn(duration: 250.ms)
                      .slideX(begin: 0.05, end: 0),
                );
        },
      )),
    ]);
  }

  Widget _catalogueListItem(Item item) {
    final cartLine   = _cart.where((l) => l.id == item.id).firstOrNull;
    final inCart     = cartLine != null;
    final atMax      = (cartLine?.qty ?? 0) >= item.stock && item.stock > 0;
    final outOfStock = item.stock == 0;
    final lowStock   = item.stock > 0 && item.stock <= 10;
    final accentColor = outOfStock ? context.hintColor : EnhancedTheme.accentCyan;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: outOfStock
                ? context.cardColor.withValues(alpha: 0.3)
                : inCart
                    ? EnhancedTheme.accentCyan.withValues(alpha: 0.07)
                    : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart
                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.35)
                  : context.borderColor,
              width: inCart ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
                      ? EnhancedTheme.errorRed.withValues(alpha: 0.1)
                      : lowStock
                          ? EnhancedTheme.warningAmber.withValues(alpha: 0.1)
                          : EnhancedTheme.successGreen.withValues(alpha: 0.08),
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
                      color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
                      fontSize: 15, fontWeight: FontWeight.w800,
                    )),
              ]),
              const SizedBox(height: 6),
              if (!outOfStock)
                atMax
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Max in cart',
                            style: TextStyle(color: EnhancedTheme.warningAmber, fontSize: 10, fontWeight: FontWeight.w600)))
                    : GestureDetector(
                        onTap: () => _addToCart(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: inCart
                                ? const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple])
                                : null,
                            color: inCart ? null : context.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: inCart ? null : Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.5)),
                          ),
                          child: Text(inCart ? '+ More' : 'Add',
                              style: TextStyle(
                                  color: inCart ? Colors.black : EnhancedTheme.accentCyan,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _catalogueGridCard(Item item) {
    final cartItem   = _cart.where((l) => l.id == item.id).firstOrNull;
    final inCart     = cartItem != null;
    final atMax      = (cartItem?.qty ?? 0) >= item.stock && item.stock > 0;
    final outOfStock = item.stock == 0;
    final lowStock   = item.stock > 0 && item.stock <= 10;
    final accentColor = outOfStock ? context.hintColor : EnhancedTheme.accentCyan;

    return GestureDetector(
      onTap: (outOfStock || atMax) ? null : () => _addToCart(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart
                      ? EnhancedTheme.accentCyan.withValues(alpha: 0.08)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: inCart ? EnhancedTheme.accentCyan.withValues(alpha: 0.45) : context.borderColor,
                width: inCart ? 1.5 : 1.0,
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
                if ((cartItem?.qty ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${cartItem!.qty}',
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
                    color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
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
                          : atMax
                              ? EnhancedTheme.warningAmber.withValues(alpha: 0.1)
                              : EnhancedTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  outOfStock ? 'Out of stock' : atMax ? 'Max in cart' : '${item.stock} left',
                  style: TextStyle(
                    color: outOfStock
                        ? EnhancedTheme.errorRed
                        : (atMax || lowStock)
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

  // ── Cart Panel (wide layout only) ─────────────────────────────────────────

  Widget _cartPanel() {
    return Column(children: [
      Expanded(child: _cart.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                    EnhancedTheme.accentPurple.withValues(alpha: 0.06),
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
              itemCount: _cart.length,
              itemBuilder: (_, i) => _WsCartItemWidget(
                key: ValueKey(_cart[i].id),
                line: _cart[i],
                onQtyChange: _updateQty,
                onRemove: _removeFromCart,
                onDiscountChange: _updateDiscount,
              ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0),
            )),

      // Summary + checkout
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(children: [
                // Gradient total row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                        EnhancedTheme.accentPurple.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_cart.length} lines · $_cartCount units',
                          style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                      const Text('Order Total', style: TextStyle(color: Colors.black87, fontSize: 12)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('₦', style: TextStyle(color: EnhancedTheme.accentCyan, fontSize: 11)),
                      Text(_cartTotal.toStringAsFixed(2),
                          style: GoogleFonts.outfit(
                              color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => setState(() { _cart.clear(); }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EnhancedTheme.errorRed,
                      side: BorderSide(color: EnhancedTheme.errorRed.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: EnhancedTheme.accentCyan.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _showPaymentSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Processing…' : 'Checkout',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _sendToCashier,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EnhancedTheme.accentOrange,
                    side: BorderSide(color: EnhancedTheme.accentOrange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send to Cashier', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Editable quantity field ───────────────────────────────────────────────────

class _WsQtyField extends StatefulWidget {
  final int quantity;
  final int maxStock;
  final ValueChanged<int> onChanged;
  const _WsQtyField({required this.quantity, required this.maxStock, required this.onChanged});

  @override
  State<_WsQtyField> createState() => _WsQtyFieldState();
}

class _WsQtyFieldState extends State<_WsQtyField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void didUpdateWidget(_WsQtyField old) {
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
            borderSide: BorderSide(color: EnhancedTheme.accentCyan, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PAYMENT SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _PaymentSheet extends StatefulWidget {
  final double total;
  final double walletBalance;
  final String customerName;
  final void Function(String method, Map<String, double> payments) onConfirm;

  const _PaymentSheet({
    required this.total,
    required this.walletBalance,
    required this.customerName,
    required this.onConfirm,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _method = 'bank_transfer';
  bool _isSubmitting = false;

  // For split payment
  final _cashCtrl     = TextEditingController();
  final _posCtrl      = TextEditingController();
  final _transferCtrl = TextEditingController();
  final _walletCtrl   = TextEditingController();

  @override
  void dispose() {
    _cashCtrl.dispose();
    _posCtrl.dispose();
    _transferCtrl.dispose();
    _walletCtrl.dispose();
    super.dispose();
  }

  Map<String, double> get _payments {
    switch (_method) {
      case 'cash':
        return {'cash': widget.total};
      case 'pos':
        return {'pos': widget.total};
      case 'bank_transfer':
        return {'bankTransfer': widget.total};
      case 'wallet':
        return {'wallet': widget.total};
      case 'split':
        return {
          'cash':         double.tryParse(_cashCtrl.text)     ?? 0,
          'pos':          double.tryParse(_posCtrl.text)      ?? 0,
          'bankTransfer': double.tryParse(_transferCtrl.text) ?? 0,
          'wallet':       double.tryParse(_walletCtrl.text)   ?? 0,
        };
      default:
        return {'bankTransfer': widget.total};
    }
  }

  bool get _splitValid {
    if (_method != 'split') return true;
    final sum = (_payments.values.fold(0.0, (a, b) => a + b));
    return (sum - widget.total).abs() < 0.01;
  }

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.97) : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.borderColor),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Gradient handle
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 20),

              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                      EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_rounded, color: EnhancedTheme.accentCyan, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Payment Method',
                      style: GoogleFonts.outfit(color: context.labelColor, fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(widget.customerName,
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 20),

              // Large amount display (calculator style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      EnhancedTheme.accentCyan.withValues(alpha: 0.18),
                      EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Text('Order Total',
                      style: TextStyle(color: context.subLabelColor, fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('₦',
                        style: GoogleFonts.outfit(color: EnhancedTheme.accentCyan, fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Text(_fmtNaira(widget.total).replaceAll('₦', ''),
                        style: GoogleFonts.outfit(
                            color: Colors.black, fontSize: 38, fontWeight: FontWeight.w800,
                            letterSpacing: -1)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              Text('Select Method',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              // Method cards — larger with gradient
              _methodCard('bank_transfer', 'Bank Transfer', Icons.account_balance_rounded, EnhancedTheme.infoBlue),
              const SizedBox(height: 8),
              _methodCard('cash', 'Cash', Icons.payments_rounded, EnhancedTheme.successGreen),
              const SizedBox(height: 8),
              _methodCard('pos', 'POS / Card', Icons.credit_card_rounded, EnhancedTheme.accentPurple),
              const SizedBox(height: 8),
              if (widget.customerName != _kWalkInName) ...[
                _methodCard('wallet', 'Wallet', Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
                const SizedBox(height: 8),
              ],
              _methodCard('split', 'Split Payment', Icons.call_split_rounded, EnhancedTheme.primaryTeal),

              // Wallet balance / debt warning
              if (_method == 'wallet' && widget.walletBalance < widget.total) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.warningAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.warningAmber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Balance ₦${widget.walletBalance.toStringAsFixed(0)} — wallet will go to '
                      '₦${(widget.walletBalance - widget.total).toStringAsFixed(0)} after this sale.',
                      style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 11),
                    )),
                  ]),
                ),
              ],

              // Split fields
              if (_method == 'split') ...[
                const SizedBox(height: 20),
                Text('Split Payment',
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _splitField(_transferCtrl, 'Bank Transfer', Icons.account_balance_rounded, EnhancedTheme.infoBlue),
                const SizedBox(height: 10),
                _splitField(_cashCtrl, 'Cash', Icons.payments_rounded, EnhancedTheme.successGreen),
                const SizedBox(height: 10),
                _splitField(_posCtrl, 'POS / Card', Icons.credit_card_rounded, EnhancedTheme.accentPurple),
                const SizedBox(height: 10),
                _splitField(_walletCtrl, 'Wallet', Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  final sum = (_payments.values.fold(0.0, (a, b) => a + b));
                  final diff = sum - widget.total;
                  final ok = diff.abs() < 0.01;
                  final label = ok
                      ? 'Balanced ✓'
                      : diff > 0
                          ? 'Over by ₦${diff.toStringAsFixed(0)}'
                          : 'Under by ₦${(-diff).toStringAsFixed(0)}';
                  final color = ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: color, size: 14),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                      Text('Sum: ₦${sum.toStringAsFixed(0)}',
                          style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    ]),
                  );
                }),
              ],

              const SizedBox(height: 28),

              // Gradient confirm button with glow
              Container(
                decoration: BoxDecoration(
                  gradient: (_isSubmitting || !_splitValid)
                      ? null
                      : const LinearGradient(colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                  color: (_isSubmitting || !_splitValid) ? Colors.grey.withValues(alpha: 0.3) : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (_isSubmitting || !_splitValid)
                      ? null
                      : [BoxShadow(color: EnhancedTheme.accentCyan.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || !_splitValid) ? null : () {
                      setState(() => _isSubmitting = true);
                      Navigator.pop(context);
                      widget.onConfirm(_method, _payments);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text('Confirm ${_fmtNaira(widget.total)}',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _methodCard(String value, String label, IconData icon, Color color) {
    final active = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)])
              : null,
          color: active ? null : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : context.borderColor,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.15) : context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? color.withValues(alpha: 0.3) : context.borderColor),
            ),
            child: Icon(icon, color: active ? color : context.subLabelColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(
            color: active ? color : context.labelColor,
            fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ))),
          if (active)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: color, size: 14),
            ),
        ]),
      ),
    );
  }

  Widget _splitField(TextEditingController ctrl, String label, IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.labelColor, fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.hintColor, fontSize: 13),
        prefixIcon: Icon(icon, color: color, size: 18),
        prefixText: '₦',
        prefixStyle: TextStyle(color: context.hintColor),
        filled: true, fillColor: context.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SUCCESS SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _WholesaleSuccessSheet extends StatelessWidget {
  final double total;
  final String customerName;
  final String receiptId;
  final String paymentMethod;
  final VoidCallback onDone;

  const _WholesaleSuccessSheet({
    required this.total,
    required this.customerName,
    required this.receiptId,
    required this.paymentMethod,
    required this.onDone,
  });

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(2)}';
  }

  (IconData, Color) get _methodMeta {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':         return (Icons.payments_rounded,                  EnhancedTheme.successGreen);
      case 'pos':          return (Icons.credit_card_rounded,               EnhancedTheme.accentPurple);
      case 'wallet':       return (Icons.account_balance_wallet_rounded,    EnhancedTheme.warningAmber);
      case 'split':        return (Icons.call_split_rounded,                EnhancedTheme.primaryTeal);
      default:             return (Icons.account_balance_rounded,           EnhancedTheme.infoBlue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _methodMeta;
    final label = paymentMethod.replaceAll('_', ' ').toUpperCase();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.97) : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Gradient handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [EnhancedTheme.successGreen, EnhancedTheme.accentCyan]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Success circle with glow
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [EnhancedTheme.successGreen, Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: EnhancedTheme.successGreen.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.black, size: 44),
            ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut),

            const SizedBox(height: 20),
            Text('Order Placed!',
                style: GoogleFonts.outfit(color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w800))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text('${_fmtNaira(total)} for $customerName',
                style: TextStyle(color: context.subLabelColor, fontSize: 14),
                textAlign: TextAlign.center)
                .animate().fadeIn(delay: 300.ms),

            if (receiptId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: Text(receiptId,
                    style: TextStyle(color: context.hintColor, fontSize: 11, fontFamily: 'monospace')),
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ).animate().fadeIn(delay: 350.ms),

            const SizedBox(height: 32),
            // Gradient confirm button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [EnhancedTheme.successGreen, Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: EnhancedTheme.successGreen.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('New Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black)),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cart line model
// ─────────────────────────────────────────────────────────────────────────────

// ── Wholesale cart item row ───────────────────────────────────────────────────

class _WsCartItemWidget extends StatefulWidget {
  final _CartLine line;
  final void Function(int id, int qty) onQtyChange;
  final void Function(int id) onRemove;
  final void Function(int id, double discount) onDiscountChange;

  const _WsCartItemWidget({
    required this.line,
    required this.onQtyChange,
    required this.onRemove,
    required this.onDiscountChange,
    super.key,
  });

  @override
  State<_WsCartItemWidget> createState() => _WsCartItemWidgetState();
}

class _WsCartItemWidgetState extends State<_WsCartItemWidget> {
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(
        text: widget.line.discount > 0 ? widget.line.discount.toStringAsFixed(0) : '');
  }

  @override
  void didUpdateWidget(_WsCartItemWidget old) {
    super.didUpdateWidget(old);
    if (old.line.discount != widget.line.discount) {
      final parsed = double.tryParse(_discountCtrl.text) ?? 0;
      if (parsed != widget.line.discount) {
        _discountCtrl.text = widget.line.discount > 0
            ? widget.line.discount.toStringAsFixed(0)
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
    final line = widget.line;
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
                    colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(line.name,
                    style: TextStyle(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                RichText(text: TextSpan(
                  style: TextStyle(color: context.subLabelColor, fontSize: 11),
                  children: [
                    TextSpan(text: '₦${line.price.toStringAsFixed(0)}'),
                    const TextSpan(text: ' × '),
                    TextSpan(text: '${line.qty}',
                        style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' = '),
                    TextSpan(text: '₦${line.total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                )),
              ])),
              const SizedBox(width: 8),
              // Colored quantity controls
              Row(children: [
                _qtyBtn(Icons.remove_rounded, () => widget.onQtyChange(line.id, line.qty - 1), color: EnhancedTheme.errorRed),
                _WsQtyField(
                  quantity: line.qty,
                  maxStock: line.stock,
                  onChanged: (n) => widget.onQtyChange(line.id, n),
                ),
                _qtyBtn(Icons.add_rounded, () => widget.onQtyChange(line.id, line.qty + 1), color: EnhancedTheme.successGreen),
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
                    widget.onDiscountChange(line.id, d);
                  },
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => widget.onRemove(line.id),
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

// ─────────────────────────────────────────────────────────────────────────────

class _CartLine {
  final int    id;
  final String name;
  final double price;
  final int    qty;
  final String barcode;
  final double discount;
  final int    stock;

  const _CartLine({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.barcode,
    this.discount = 0,
    this.stock = 9999,
  });

  double get total => (price * qty) - discount;

  _CartLine copyWith({int? qty, double? discount}) => _CartLine(
    id: id, name: name, price: price, barcode: barcode, stock: stock,
    qty: qty ?? this.qty,
    discount: discount ?? this.discount,
  );
}

// ── Snack type helper ─────────────────────────────────────────────────────────
enum _SnackType { success, error, warning }
