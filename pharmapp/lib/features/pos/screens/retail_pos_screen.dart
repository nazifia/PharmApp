import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/models/cart_item.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/cart_provider.dart';

class RetailPOSScreen extends ConsumerStatefulWidget {
  const RetailPOSScreen({super.key});

  @override
  ConsumerState<RetailPOSScreen> createState() => _RetailPOSScreenState();
}

class _RetailPOSScreenState extends ConsumerState<RetailPOSScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _checkout() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    context.push('/payment');
  }

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
        builder: (ctx, scrollCtrl) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) => Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.borderColor)),
              child: Column(children: [
                const SizedBox(height: 12),
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    Text('Select Customer', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ref.read(selectedCustomerProvider.notifier).state = null;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear', style: TextStyle(color: EnhancedTheme.errorRed))),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    style: TextStyle(color: context.labelColor),
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      hintStyle: TextStyle(color: context.hintColor),
                      prefixIcon: Icon(Icons.search, color: context.hintColor, size: 20),
                      filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: Builder(builder: (_) {
                  final q = searchCtrl.text.toLowerCase();
                  final filtered = customers.where((c) =>
                      c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
                  if (filtered.isEmpty) return Center(child: Text('No customers found', style: TextStyle(color: context.hintColor)));
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
                          backgroundColor: (c.isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal).withValues(alpha: 0.2),
                          child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                              style: TextStyle(color: c.isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(c.name, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text(c.phone, style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: EnhancedTheme.primaryTeal) : null,
                      );
                    },
                  );
                })),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query        = _searchCtrl.text;
    final catalogAsync = query.isNotEmpty
        ? ref.watch(inventorySearchProvider(query))
        : ref.watch(inventoryListProvider);
    final cart         = ref.watch(cartProvider);
    final cartTotal    = ref.read(cartProvider.notifier).cartTotal;
    final cartCount    = cart.fold<int>(0, (s, c) => s + c.quantity);
    final selected     = ref.watch(selectedCustomerProvider);
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(child: Text('Retail POS', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w600))),
              if (cartCount > 0) GestureDetector(
                onTap: _checkout,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text('$cartCount  ·  ₦${cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),

          // Customer selector
          Padding(
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
                      ? EnhancedTheme.accentCyan.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected != null
                      ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1))),
                child: Row(children: [
                  Icon(Icons.person_rounded,
                      color: selected != null ? EnhancedTheme.accentCyan : context.hintColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: selected != null
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(selected.name,
                              style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('Wallet: ₦${selected.walletBalance.toStringAsFixed(0)}',
                              style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                        ])
                      : Text('Link a customer (optional)',
                          style: TextStyle(color: context.hintColor, fontSize: 13))),
                  Icon(Icons.arrow_drop_down_rounded, color: context.hintColor),
                ]),
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: TextField(
                  controller: _searchCtrl, onChanged: (_) => setState(() {}),
                  style: TextStyle(color: context.labelColor),
                  decoration: InputDecoration(
                    hintText: 'Search items…',
                    hintStyle: TextStyle(color: context.hintColor),
                    prefixIcon: Icon(Icons.search, color: context.hintColor),
                    filled: true, fillColor: context.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // Catalogue
          Expanded(child: catalogAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(inventoryListProvider),
                  child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (items) => GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1),
              itemCount: items.length,
              itemBuilder: (_, i) => _catalogueCard(items[i], cart),
            ),
          )),

          // Cart summary bar
          if (cart.isNotEmpty) _cartBar(cart, cartTotal),
        ])),
      ]),
    );
  }

  Widget _catalogueCard(Item item, List<CartItem> cartItems) {
    final cartItem = cartItems.where((c) => c.item.id == item.id).firstOrNull;
    final inCart   = cartItem?.quantity ?? 0;
    final outOfStock = item.stock == 0;

    return GestureDetector(
      onTap: outOfStock ? null : () => ref.read(cartProvider.notifier).addItem(item),
      child: ClipRRect(borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart > 0
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.12)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: inCart > 0 ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4) : context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(Icons.medication_rounded,
                    color: outOfStock ? Colors.white24 : EnhancedTheme.primaryTeal, size: 22),
                if (inCart > 0) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: EnhancedTheme.primaryTeal, borderRadius: BorderRadius.circular(8)),
                  child: Text('$inCart', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
              const Spacer(),
              Text(item.name, style: TextStyle(
                  color: outOfStock ? context.hintColor : context.labelColor,
                  fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('₦${item.price.toStringAsFixed(0)}',
                  style: TextStyle(color: outOfStock ? Colors.white24 : EnhancedTheme.primaryTeal,
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(outOfStock ? 'Out of stock' : '${item.stock} left',
                  style: TextStyle(
                      color: outOfStock ? EnhancedTheme.errorRed.withValues(alpha: 0.7) : context.hintColor,
                      fontSize: 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _cartBar(List<CartItem> cart, double total) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: EnhancedTheme.primaryTeal,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${cart.fold<int>(0, (s, c) => s + c.quantity)} items in cart',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text('₦${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ])),
      Row(children: [
        TextButton(
          onPressed: () {
            ref.read(cartProvider.notifier).clearCart();
            ref.read(selectedCustomerProvider.notifier).state = null;
          },
          child: const Text('Clear', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _checkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, foregroundColor: EnhancedTheme.primaryTeal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    ]),
  );
}
