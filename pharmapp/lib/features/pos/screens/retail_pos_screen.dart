import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../../inventory/providers/inventory_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final query        = _searchCtrl.text;
    final catalogAsync = query.isNotEmpty
        ? ref.watch(inventorySearchProvider(query))
        : ref.watch(inventoryListProvider);
    final cart         = ref.watch(cartProvider);
    final cartTotal    = ref.read(cartProvider.notifier).cartTotal;
    final cartCount    = cart.fold(0, (s, c) => s + c.quantity);

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
                    Text('$cartCount  ·  ₹${cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: TextField(
                  controller: _searchCtrl, onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search items…',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4)),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
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
              Icon(Icons.cloud_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13), textAlign: TextAlign.center),
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

  Widget _catalogueCard(Item item, cartItems) {
    final cartItem = (cartItems as List).cast().where((c) => c.item.id == item.id).firstOrNull;
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
              Text('₹${item.price.toStringAsFixed(0)}',
                  style: TextStyle(color: outOfStock ? Colors.white24 : EnhancedTheme.primaryTeal,
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(outOfStock ? 'Out of stock' : '${item.stock} left',
                  style: TextStyle(
                      color: outOfStock ? EnhancedTheme.errorRed.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.4),
                      fontSize: 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _cartBar(List cart, double total) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: EnhancedTheme.primaryTeal,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${cart.fold(0, (s, c) => s + (c.quantity as int))} items in cart',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text('₹${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ])),
      Row(children: [
        TextButton(
          onPressed: () { ref.read(cartProvider.notifier).clearCart(); },
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
