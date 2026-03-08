import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/models/sale.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/pos_api_provider.dart';

class WholesalePOSScreen extends ConsumerStatefulWidget {
  const WholesalePOSScreen({super.key});

  @override
  ConsumerState<WholesalePOSScreen> createState() => _WholesalePOSScreenState();
}

class _WholesalePOSScreenState extends ConsumerState<WholesalePOSScreen> {
  final _searchCtrl       = TextEditingController();
  int?   _selectedId;
  String? _selectedName;
  final List<_CartLine> _cart = [];
  bool _isSubmitting = false;

  double get _cartTotal => _cart.fold(0, (s, l) => s + l.total);
  int    get _cartCount => _cart.fold(0, (s, l) => s + l.qty);

  void _addToCart(Item item) {
    final idx = _cart.indexWhere((l) => l.id == item.id);
    setState(() {
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWithQty(_cart[idx].qty + 1);
      } else {
        _cart.add(_CartLine(id: item.id, name: item.name,
            price: item.price, qty: 1, barcode: item.barcode));
      }
    });
  }

  void _removeFromCart(int id) =>
      setState(() => _cart.removeWhere((l) => l.id == id));

  void _updateQty(int id, int qty) {
    if (qty <= 0) { _removeFromCart(id); return; }
    setState(() {
      final idx = _cart.indexWhere((l) => l.id == id);
      if (idx >= 0) _cart[idx] = _cart[idx].copyWithQty(qty);
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    if (_selectedId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final payload = CheckoutPayload(
        items: _cart.map((l) => SaleItemPayload(
          barcode: l.barcode, quantity: l.qty, unitPrice: l.price,
        )).toList(),
        payments: PaymentPayload(bankTransfer: _cartTotal),
        customerId: _selectedId.toString(),
        totalAmount: _cartTotal,
      );
      await ref.read(posApiProvider).submitCheckout(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Order placed for $_selectedName — ₦${_cartTotal.toStringAsFixed(2)}')));
      setState(() { _cart.clear(); _selectedId = null; _selectedName = null; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: EnhancedTheme.errorRed));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final customersAsync = ref.watch(customerListProvider);
    final wide = MediaQuery.of(context).size.width > 800;

    // Only wholesale customers
    final wholesaleAsync = customersAsync.whenData(
        (list) => list.where((c) => c.isWholesale).toList());

    // Filter by search query
    final filteredAsync = inventoryAsync.whenData((items) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isEmpty) return items;
      return items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.brand.toLowerCase().contains(q)).toList();
    });

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          SafeArea(child: Column(children: [
            _header(context),
            Expanded(child: wide
                ? Row(children: [
                    Expanded(flex: 3, child: _itemsPanel(filteredAsync)),
                    const VerticalDivider(width: 1, color: Colors.white12),
                    Expanded(flex: 2, child: _cartPanel(wholesaleAsync)),
                  ])
                : _mobileLayout(filteredAsync, wholesaleAsync)),
          ])),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop()),
        const SizedBox(width: 4),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wholesale POS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          Text('Bulk order processing', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: EnhancedTheme.accentCyan.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.accentCyan.withOpacity(0.3)),
          ),
          child: Text('$_cartCount items',
              style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _mobileLayout(AsyncValue<List<Item>> filtered,
      AsyncValue<List<Customer>> wholesale) {
    final count = filtered.whenOrNull(data: (l) => l.length) ?? 0;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: EnhancedTheme.accentCyan,
          unselectedLabelColor: Colors.white38,
          indicatorColor: EnhancedTheme.accentCyan,
          tabs: [
            Tab(text: 'Catalogue ($count)'),
            Tab(text: 'Cart (${_cart.length})'),
          ],
        ),
        Expanded(child: TabBarView(children: [
          _itemsPanel(filtered), _cartPanel(wholesale),
        ])),
      ]),
    );
  }

  Widget _itemsPanel(AsyncValue<List<Item>> filtered) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search catalogue…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 20),
                filled: true, fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: filtered.when(
        loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.accentCyan)),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text('$e', style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
          TextButton(onPressed: () => ref.invalidate(inventoryListProvider),
              child: const Text('Retry', style: TextStyle(color: EnhancedTheme.accentCyan))),
        ])),
        data: (items) => items.isEmpty
            ? Center(child: Text('No items found',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: items.length,
                itemBuilder: (_, i) => _catalogueItem(items[i]),
              ),
      )),
    ]);
  }

  Widget _catalogueItem(Item item) {
    final inCart     = _cart.any((l) => l.id == item.id);
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
                ? Colors.white.withOpacity(0.03)
                : inCart
                    ? EnhancedTheme.accentCyan.withOpacity(0.08)
                    : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: inCart
                ? EnhancedTheme.accentCyan.withOpacity(0.3)
                : Colors.white.withOpacity(0.09)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan.withOpacity(outOfStock ? 0.05 : 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.medication_rounded,
                  color: outOfStock ? Colors.white24 : EnhancedTheme.accentCyan, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: TextStyle(
                  color: outOfStock ? Colors.white30 : Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              Text(item.brand, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
              Text(outOfStock ? 'Out of stock' : '${item.stock} in stock',
                  style: TextStyle(
                      color: outOfStock
                          ? EnhancedTheme.errorRed.withOpacity(0.7)
                          : Colors.white.withOpacity(0.35),
                      fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₦${item.price.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: outOfStock ? Colors.white24 : EnhancedTheme.accentCyan,
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (!outOfStock)
                GestureDetector(
                  onTap: () => _addToCart(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EnhancedTheme.primaryTeal.withOpacity(0.3)),
                    ),
                    child: Text(inCart ? '+ More' : 'Add',
                        style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _cartPanel(AsyncValue<List<Customer>> wholesaleAsync) {
    return Column(children: [
      // Customer selector
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: wholesaleAsync.when(
          loading: () => const LinearProgressIndicator(color: EnhancedTheme.accentCyan),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Failed to load customers',
                style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 12)),
          ),
          data: (customers) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedId,
                    hint: Text('Select wholesale customer',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    iconEnabledColor: Colors.white38,
                    items: customers.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() {
                      _selectedId   = v;
                      _selectedName = customers.firstWhere((c) => c.id == v).name;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // Cart items
      Expanded(child: _cart.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.white.withOpacity(0.2), size: 52),
              const SizedBox(height: 12),
              Text('No items in cart',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: _cart.length,
              itemBuilder: (_, i) => _cartItem(_cart[i]),
            )),

      // Totals + checkout
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_cart.length} items  ·  $_cartCount units',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                  Text('₦${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Processing…' : 'Place Wholesale Order',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _cartItem(_CartLine line) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('₦${line.price.toStringAsFixed(0)} × ${line.qty} = ₦${line.total.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ])),
            Row(children: [
              _qtyBtn(Icons.remove, () => _updateQty(line.id, line.qty - 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${line.qty}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              _qtyBtn(Icons.add, () => _updateQty(line.id, line.qty + 1)),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    ),
  );
}

class _CartLine {
  final int id;
  final String name;
  final double price;
  final int qty;
  final String barcode;

  const _CartLine({
    required this.id, required this.name,
    required this.price, required this.qty, required this.barcode,
  });

  double get total => price * qty;
  _CartLine copyWithQty(int q) =>
      _CartLine(id: id, name: name, price: price, qty: q, barcode: barcode);
}
