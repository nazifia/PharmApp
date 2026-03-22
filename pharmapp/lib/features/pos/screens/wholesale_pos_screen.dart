import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          builder: (ctx, setSheetState) => Container(
            decoration: BoxDecoration(
              color: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: ctx.borderColor),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: ctx.hintColor, borderRadius: BorderRadius.circular(2)),
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Text('Select Customer',
                      style: TextStyle(color: ctx.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCustomerId = null;
                        _selectedCustomerName = null;
                        _selectedCustomerWallet = 0;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear', style: TextStyle(color: EnhancedTheme.errorRed)),
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
                    prefixIcon: Icon(Icons.search, color: ctx.hintColor, size: 20),
                    filled: true, fillColor: ctx.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Walk-in customer shortcut
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  tileColor: _selectedCustomerId == _kWalkInId
                      ? EnhancedTheme.accentOrange.withValues(alpha: 0.12)
                      : ctx.cardColor,
                  leading: CircleAvatar(
                    backgroundColor: EnhancedTheme.accentOrange.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_outline, color: EnhancedTheme.accentOrange, size: 20),
                  ),
                  title: Text(_kWalkInName,
                      style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('No account required',
                      style: TextStyle(color: ctx.hintColor, fontSize: 12)),
                  trailing: _selectedCustomerId == _kWalkInId
                      ? const Icon(Icons.check_circle, color: EnhancedTheme.accentOrange)
                      : null,
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
                      Icon(Icons.people_outline, color: ctx.hintColor, size: 48),
                      const SizedBox(height: 12),
                      Text('No wholesale customers found',
                          style: TextStyle(color: ctx.subLabelColor, fontSize: 14)),
                    ],
                  ));
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final isSelected = _selectedCustomerId == c.id;
                    return ListTile(
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
                          style: const TextStyle(
                              color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(c.name,
                          style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.phone,
                            style: TextStyle(color: ctx.subLabelColor, fontSize: 12)),
                        if (c.walletBalance > 0)
                          Text('Wallet: ₦${c.walletBalance.toStringAsFixed(0)}',
                              style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11)),
                        if (c.outstandingDebt > 0)
                          Text('Debt: ₦${c.outstandingDebt.toStringAsFixed(0)}',
                              style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 11)),
                      ]),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: EnhancedTheme.accentCyan)
                          : null,
                    );
                  },
                );
              })),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Payment method sheet ──────────────────────────────────────────────────

  void _showPaymentSheet() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty')));
      return;
    }
    if (_selectedCustomerName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer or choose Walk-in')));
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
      final receiptId = result['receiptId'] as String? ?? result['receipt_id'] as String? ?? '';
      setState(() {
        _cart.clear();
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _selectedCustomerWallet = 0;
      });

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
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data is Map && e.response!.data['detail'] != null
              ? e.response!.data['detail'].toString()
              : 'Checkout failed (${e.response?.statusCode ?? e.message})')
          : 'Checkout failed: $e';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: EnhancedTheme.errorRed,
              duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Send to cashier ────────────────────────────────────────────────────────

  Future<void> _sendToCashier() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty')));
      return;
    }
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
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment request sent to cashier'),
        backgroundColor: EnhancedTheme.successGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data is Map && e.response!.data['detail'] != null
              ? e.response!.data['detail'].toString()
              : 'Request failed (${e.response?.statusCode ?? e.message})')
          : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: EnhancedTheme.errorRed));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(wholesaleInventoryProvider);
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
          if (_cart.isNotEmpty && !wide) _cartBar(),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
        onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
      ),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Wholesale POS',
            style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600)),
        Text('Bulk order processing',
            style: TextStyle(color: context.hintColor, fontSize: 11)),
      ])),
      // Grid/List toggle
      GestureDetector(
        onTap: () => setState(() => _gridView = !_gridView),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderColor),
          ),
          child: Icon(
            _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: context.labelColor, size: 18,
          ),
        ),
      ),
      const SizedBox(width: 8),
      if (_cartCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
          ),
          child: Text('$_cartCount',
              style: const TextStyle(
                  color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
    ]),
  );

  // ── Customer Row ────────────────────────────────────────────────────────────

  Widget _customerRow(BuildContext context, AsyncValue<List<Customer>> customersAsync) {
    final hasCustomer = _selectedCustomerId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GestureDetector(
        onTap: () {
          final customers = customersAsync.valueOrNull ?? [];
          _showCustomerPicker(customers);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasCustomer
                ? EnhancedTheme.accentCyan.withValues(alpha: 0.12)
                : context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasCustomer
                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                  : context.borderColor,
            ),
          ),
          child: Row(children: [
            Icon(Icons.store_rounded,
                color: hasCustomer ? EnhancedTheme.accentCyan : context.hintColor, size: 20),
            const SizedBox(width: 10),
            Expanded(child: hasCustomer
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selectedCustomerName!,
                        style: TextStyle(color: context.labelColor,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Wallet: ₦${_selectedCustomerWallet.toStringAsFixed(0)}',
                        style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  ])
                : Text('Select wholesale customer',
                    style: TextStyle(color: context.hintColor, fontSize: 13))),
            Icon(Icons.arrow_drop_down_rounded, color: context.hintColor),
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
          color: context.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          child: TabBar(
            labelColor: EnhancedTheme.accentCyan,
            unselectedLabelColor: context.hintColor,
            indicatorColor: EnhancedTheme.accentCyan,
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
            hintText: 'Search items…',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: context.hintColor, size: 20),
            filled: true, fillColor: context.cardColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      Expanded(child: filtered.when(
        loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.accentCyan)),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
          const SizedBox(height: 12),
          Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
          TextButton(
            onPressed: () => ref.invalidate(wholesaleInventoryProvider),
            child: const Text('Retry', style: TextStyle(color: EnhancedTheme.accentCyan)),
          ),
        ])),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inventory_2_outlined, color: context.hintColor, size: 52),
              const SizedBox(height: 12),
              Text('No items found', style: TextStyle(color: context.subLabelColor, fontSize: 14)),
            ]));
          }
          return _gridView
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueGridCard(items[i]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueListItem(items[i]),
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
                    ? EnhancedTheme.accentCyan.withValues(alpha: 0.08)
                    : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart
                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.3)
                  : context.borderColor,
            ),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (outOfStock ? context.hintColor : EnhancedTheme.accentCyan)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.medication_rounded,
                  color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: TextStyle(
                      color: outOfStock ? context.hintColor : context.labelColor,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (item.brand.isNotEmpty)
                Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              Text(outOfStock ? 'Out of stock' : '${item.stock} in stock',
                  style: TextStyle(
                    color: outOfStock
                        ? EnhancedTheme.errorRed.withValues(alpha: 0.7)
                        : context.hintColor,
                    fontSize: 10,
                  )),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₦${item.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
                    fontSize: 14, fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 4),
              if (!outOfStock)
                atMax
                    ? const Text('Max in cart',
                        style: TextStyle(color: EnhancedTheme.warningAmber, fontSize: 10, fontWeight: FontWeight.w600))
                    : GestureDetector(
                        onTap: () => _addToCart(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                          ),
                          child: Text(inCart ? '+ More' : 'Add',
                              style: const TextStyle(
                                  color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
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

    return GestureDetector(
      onTap: (outOfStock || atMax) ? null : () => _addToCart(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart
                      ? EnhancedTheme.accentCyan.withValues(alpha: 0.08)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: inCart ? EnhancedTheme.accentCyan.withValues(alpha: 0.4) : context.borderColor,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(Icons.medication_rounded,
                    color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan, size: 22),
                if ((cartItem?.qty ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: EnhancedTheme.accentCyan, borderRadius: BorderRadius.circular(8)),
                    child: Text('${cartItem!.qty}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
              const SizedBox(height: 2),
              Text(outOfStock ? 'Out of stock' : atMax ? 'Max in cart' : '${item.stock} left',
                  style: TextStyle(
                    color: outOfStock
                        ? EnhancedTheme.errorRed.withValues(alpha: 0.7)
                        : atMax
                            ? EnhancedTheme.warningAmber
                            : context.hintColor,
                    fontSize: 10,
                  )),
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
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart_outlined, color: context.hintColor, size: 52),
              const SizedBox(height: 12),
              Text('No items in cart', style: TextStyle(color: context.subLabelColor, fontSize: 14)),
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
              ),
            )),

      // Summary + checkout
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_cart.length} lines  ·  $_cartCount units',
                      style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                  Text('₦${_cartTotal.toStringAsFixed(2)}',
                      style: TextStyle(color: context.labelColor,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => setState(() {
                      _cart.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EnhancedTheme.errorRed,
                      side: BorderSide(color: EnhancedTheme.errorRed.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Clear'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _showPaymentSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Processing…' : 'Checkout',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _sendToCashier,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EnhancedTheme.accentOrange,
                    side: BorderSide(color: EnhancedTheme.accentOrange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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


  // ── Cart bar (mobile bottom) ───────────────────────────────────────────────

  Widget _cartBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: EnhancedTheme.accentCyan,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$_cartCount items  ·  ${_cart.length} lines',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text('₦${_cartTotal.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      ])),
      TextButton(
        onPressed: () => setState(() => _cart.clear()),
        child: const Text('Clear', style: TextStyle(color: Colors.white70)),
      ),
      const SizedBox(width: 4),
      OutlinedButton.icon(
        onPressed: _isSubmitting ? null : _sendToCashier,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        icon: const Icon(Icons.send_rounded, size: 14),
        label: const Text('Cashier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 6),
      ElevatedButton(
        onPressed: _isSubmitting ? null : _showPaymentSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: EnhancedTheme.accentCyan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Icon(icon, color: context.labelColor, size: 16),
    ),
  );
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
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),

          Text('Payment Method',
              style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(widget.customerName,
              style: TextStyle(color: context.subLabelColor, fontSize: 13)),
          const SizedBox(height: 20),

          // Order total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Order Total',
                  style: TextStyle(color: context.subLabelColor, fontSize: 14)),
              Text(_fmtNaira(widget.total),
                  style: const TextStyle(color: EnhancedTheme.primaryTeal,
                      fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 20),

          Text('Select Method',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Method chips
          Wrap(spacing: 10, runSpacing: 10, children: [
            _methodChip('bank_transfer', 'Bank Transfer', Icons.account_balance_rounded, EnhancedTheme.infoBlue),
            _methodChip('cash',          'Cash',          Icons.payments_rounded,         EnhancedTheme.successGreen),
            _methodChip('pos',           'POS / Card',    Icons.credit_card_rounded,      EnhancedTheme.accentPurple),
            if (widget.customerName != _kWalkInName)
              _methodChip('wallet', 'Wallet', Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
            _methodChip('split',         'Split',         Icons.call_split_rounded,       EnhancedTheme.primaryTeal),
          ]),

          // Wallet balance / debt warning
          if (_method == 'wallet' && widget.walletBalance < widget.total) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EnhancedTheme.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.warningAmber, size: 15),
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
                style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _splitField(_transferCtrl, 'Bank Transfer', Icons.account_balance_rounded, EnhancedTheme.infoBlue),
            const SizedBox(height: 10),
            _splitField(_cashCtrl, 'Cash', Icons.payments_rounded, EnhancedTheme.successGreen),
            const SizedBox(height: 10),
            _splitField(_posCtrl, 'POS / Card', Icons.credit_card_rounded, EnhancedTheme.accentPurple),
            const SizedBox(height: 10),
            _splitField(_walletCtrl, 'Wallet', Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final sum = (_payments.values.fold(0.0, (a, b) => a + b));
              final diff = sum - widget.total;
              final label = diff.abs() < 0.01
                  ? 'Balanced ✓'
                  : diff > 0
                      ? 'Over by ₦${diff.toStringAsFixed(0)}'
                      : 'Under by ₦${(-diff).toStringAsFixed(0)}';
              final color = diff.abs() < 0.01
                  ? EnhancedTheme.successGreen
                  : EnhancedTheme.errorRed;
              return Text(label,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600));
            }),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isSubmitting || !_splitValid) ? null : () {
                setState(() => _isSubmitting = true);
                Navigator.pop(context);
                widget.onConfirm(_method, _payments);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.accentCyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Confirm ${_fmtNaira(widget.total)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _methodChip(String value, String label, IconData icon, Color color) {
    final active = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : context.borderColor,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? color : context.subLabelColor, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: active ? color : context.subLabelColor,
            fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          )),
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

    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: EnhancedTheme.successGreen, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text('Order Placed!',
            style: TextStyle(color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${_fmtNaira(total)} for $customerName',
            style: TextStyle(color: context.subLabelColor, fontSize: 14),
            textAlign: TextAlign.center),
        if (receiptId.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(receiptId,
              style: TextStyle(color: context.hintColor, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('New Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        )),
      ]),
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
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(line.name,
                    style: TextStyle(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('₦${line.price.toStringAsFixed(0)} × ${line.qty} = ₦${line.total.toStringAsFixed(0)}',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              Row(children: [
                _qtyBtn(Icons.remove, () => widget.onQtyChange(line.id, line.qty - 1)),
                _WsQtyField(
                  quantity: line.qty,
                  maxStock: line.stock,
                  onChanged: (n) => widget.onQtyChange(line.id, n),
                ),
                _qtyBtn(Icons.add, () => widget.onQtyChange(line.id, line.qty + 1)),
              ]),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.discount_outlined, color: context.hintColor, size: 14),
              const SizedBox(width: 6),
              Text('Discount:', style: TextStyle(color: context.hintColor, fontSize: 11)),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                height: 26,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.labelColor, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    hintText: '0',
                    hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
                    filled: true, fillColor: context.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                        borderSide: BorderSide(color: EnhancedTheme.accentCyan, width: 1.5)),
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
                child: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Icon(icon, color: context.labelColor, size: 16),
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
