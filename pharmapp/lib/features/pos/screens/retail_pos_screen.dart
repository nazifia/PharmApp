import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/cart_item.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty')));
      return;
    }
    context.push('/payment');
  }

  Future<void> _sendToCashier() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty')));
      return;
    }
    final items = cart.map((c) => {
      'itemId': c.item.id,
      'barcode': c.item.barcode,
      'quantity': c.quantity,
      'price': c.item.price,
      'discount': c.discount,
    }).toList();
    final customerId = ref.read(selectedCustomerProvider)?.id;
    try {
      await ref.read(posApiProvider).sendToCashier(items, customerId: customerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment request sent to cashier'),
        backgroundColor: EnhancedTheme.successGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: EnhancedTheme.errorRed));
    }
  }

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
                      ref.read(selectedCustomerProvider.notifier).state = null;
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
                    hintText: 'Search customers…',
                    hintStyle: TextStyle(color: ctx.hintColor),
                    prefixIcon: Icon(Icons.search, color: ctx.hintColor, size: 20),
                    filled: true, fillColor: ctx.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                      Icon(Icons.people_outline, color: ctx.hintColor, size: 48),
                      const SizedBox(height: 12),
                      Text('No customers found',
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
                    final isSelected = ref.read(selectedCustomerProvider)?.id == c.id;
                    return ListTile(
                      onTap: () {
                        ref.read(selectedCustomerProvider.notifier).state = SelectedCustomer(
                          id: c.id, name: c.name, walletBalance: c.walletBalance);
                        Navigator.pop(ctx);
                      },
                      leading: CircleAvatar(
                        backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(c.name,
                          style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.phone, style: TextStyle(color: ctx.subLabelColor, fontSize: 12)),
                        if (c.walletBalance > 0)
                          Text('Wallet: ₦${c.walletBalance.toStringAsFixed(0)}',
                              style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11)),
                      ]),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: EnhancedTheme.primaryTeal)
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(retailInventoryProvider);
    final customersAsync = ref.watch(customerListProvider);
    final cart           = ref.watch(cartProvider);
    final cartTotal      = ref.read(cartProvider.notifier).cartTotal;
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
          if (cart.isNotEmpty && !wide) _cartBar(cart, cartTotal),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, int cartCount) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
        onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
      ),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Retail POS',
            style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600)),
        Text('Retail dispensing',
            style: TextStyle(color: context.hintColor, fontSize: 11)),
      ])),
      // Grid / List toggle
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
      if (cartCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
          ),
          child: Text('$cartCount',
              style: const TextStyle(
                  color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
    ]),
  );

  // ── Customer Row ───────────────────────────────────────────────────────────

  Widget _customerRow(BuildContext context, AsyncValue customersAsync) {
    final selected = ref.watch(selectedCustomerProvider);
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
            color: selected != null
                ? EnhancedTheme.primaryTeal.withValues(alpha: 0.12)
                : context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected != null
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4)
                  : context.borderColor,
            ),
          ),
          child: Row(children: [
            Icon(Icons.person_rounded,
                color: selected != null ? EnhancedTheme.primaryTeal : context.hintColor, size: 20),
            const SizedBox(width: 10),
            Expanded(child: selected != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(selected.name,
                        style: TextStyle(color: context.labelColor,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Wallet: ₦${selected.walletBalance.toStringAsFixed(0)}',
                        style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  ])
                : Text('Link a customer (optional)',
                    style: TextStyle(color: context.hintColor, fontSize: 13))),
            Icon(Icons.arrow_drop_down_rounded, color: context.hintColor),
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
          color: context.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          child: TabBar(
            labelColor: EnhancedTheme.primaryTeal,
            unselectedLabelColor: context.hintColor,
            indicatorColor: EnhancedTheme.primaryTeal,
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
        loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
          const SizedBox(height: 12),
          Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
          TextButton(
            onPressed: () => ref.invalidate(retailInventoryProvider),
            child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal)),
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
                  itemBuilder: (_, i) => _catalogueGridCard(items[i], cart),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueListItem(items[i], cart),
                );
        },
      )),
    ]);
  }

  Widget _catalogueListItem(Item item, List<CartItem> cart) {
    final cartItem   = cart.where((c) => c.item.id == item.id).firstOrNull;
    final inCart     = cartItem?.quantity ?? 0;
    final outOfStock = item.stock == 0;
    final atStockCap = inCart >= item.stock;

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
                : inCart > 0
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.08)
                    : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart > 0
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.3)
                  : context.borderColor,
            ),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (outOfStock ? context.hintColor : EnhancedTheme.primaryTeal)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.medication_rounded,
                  color: outOfStock ? context.hintColor : EnhancedTheme.primaryTeal, size: 22),
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
                    color: outOfStock ? context.hintColor : EnhancedTheme.primaryTeal,
                    fontSize: 14, fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 4),
              if (!outOfStock && !atStockCap)
                GestureDetector(
                  onTap: () => ref.read(cartProvider.notifier).addItem(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                    ),
                    child: Text(inCart > 0 ? '+ More' : 'Add',
                        style: const TextStyle(
                            color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (atStockCap && inCart > 0)
                Text('Max stock', style: TextStyle(color: context.hintColor, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _catalogueGridCard(Item item, List<CartItem> cart) {
    final cartItem   = cart.where((c) => c.item.id == item.id).firstOrNull;
    final inCart     = cartItem?.quantity ?? 0;
    final outOfStock = item.stock == 0;
    final atStockCap = inCart >= item.stock;

    return GestureDetector(
      onTap: (outOfStock || atStockCap) ? null : () => ref.read(cartProvider.notifier).addItem(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart > 0
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.08)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: inCart > 0
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4)
                    : context.borderColor,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(Icons.medication_rounded,
                    color: outOfStock ? context.hintColor : EnhancedTheme.primaryTeal, size: 22),
                if (inCart > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal, borderRadius: BorderRadius.circular(8)),
                    child: Text('$inCart',
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
                    color: outOfStock ? context.hintColor : EnhancedTheme.primaryTeal,
                    fontSize: 14, fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 2),
              Text(outOfStock ? 'Out of stock' : atStockCap ? 'Max in cart' : '${item.stock} left',
                  style: TextStyle(
                    color: (outOfStock || atStockCap)
                        ? EnhancedTheme.errorRed.withValues(alpha: 0.7)
                        : context.hintColor,
                    fontSize: 10,
                  )),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Cart Panel (wide layout) ───────────────────────────────────────────────

  Widget _cartPanel(List<CartItem> cart, double cartTotal) {
    return Column(children: [
      Expanded(child: cart.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart_outlined, color: context.hintColor, size: 52),
              const SizedBox(height: 12),
              Text('No items in cart', style: TextStyle(color: context.subLabelColor, fontSize: 14)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: cart.length,
              itemBuilder: (_, i) => _cartItemRow(cart[i]),
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
                  Text('${cart.length} lines  ·  ${cart.fold<int>(0, (s, c) => s + c.quantity)} units',
                      style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                  Text('₦${cartTotal.toStringAsFixed(2)}',
                      style: TextStyle(color: context.labelColor,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clearCart();
                      ref.read(selectedCustomerProvider.notifier).state = null;
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EnhancedTheme.errorRed,
                      side: BorderSide(color: EnhancedTheme.errorRed.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Clear'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _sendToCashier,
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

  Widget _cartItemRow(CartItem c) {
    final discountCtrl = TextEditingController(
        text: c.discount > 0 ? c.discount.toStringAsFixed(0) : '');

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
                Text(c.item.name,
                    style: TextStyle(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('₦${c.item.price.toStringAsFixed(0)} × ${c.quantity} = ₦${c.total.toStringAsFixed(0)}',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              Row(children: [
                _qtyBtn(Icons.remove,
                    () => ref.read(cartProvider.notifier).updateQuantity(c.item.id, c.quantity - 1)),
                _QtyField(
                  quantity: c.quantity,
                  maxStock: c.item.stock,
                  onChanged: (n) => ref.read(cartProvider.notifier).updateQuantity(c.item.id, n),
                ),
                _qtyBtn(Icons.add,
                    () => ref.read(cartProvider.notifier).updateQuantity(c.item.id, c.quantity + 1)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.discount_outlined, color: context.hintColor, size: 14),
              const SizedBox(width: 6),
              Text('Discount:', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 28,
                child: TextField(
                  controller: discountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: context.labelColor, fontSize: 12),
                  onChanged: (v) => ref.read(cartProvider.notifier)
                      .updateDiscount(c.item.id, double.tryParse(v) ?? 0),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: context.hintColor, fontSize: 11),
                    prefixText: '₦',
                    prefixStyle: TextStyle(color: context.hintColor, fontSize: 11),
                    filled: true,
                    fillColor: context.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.borderColor)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(cartProvider.notifier).removeItem(c.item.id),
                child: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Cart bar (mobile bottom) ───────────────────────────────────────────────

  Widget _cartBar(List<CartItem> cart, double cartTotal) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: EnhancedTheme.primaryTeal,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${cart.fold<int>(0, (s, c) => s + c.quantity)} items  ·  ${cart.length} lines',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text('₦${cartTotal.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      ])),
      TextButton(
        onPressed: () {
          ref.read(cartProvider.notifier).clearCart();
          ref.read(selectedCustomerProvider.notifier).state = null;
        },
        child: const Text('Clear', style: TextStyle(color: Colors.white70)),
      ),
      const SizedBox(width: 4),
      OutlinedButton.icon(
        onPressed: _sendToCashier,
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
        onPressed: _checkout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: EnhancedTheme.primaryTeal,
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
