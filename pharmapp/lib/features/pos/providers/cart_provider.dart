import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Item item) {
    if (item.stock == 0) return;
    final existingIndex = state.indexWhere((c) => c.item.id == item.id);
    if (existingIndex >= 0) {
      final current = state[existingIndex];
      if (current.quantity >= item.stock) return; // stock cap
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            state[i].copyWith(quantity: state[i].quantity + 1)
          else
            state[i]
      ];
    } else {
      state = [...state, CartItem(item: item, quantity: 1, discount: 0.0)];
    }
  }

  void removeItem(int itemId) {
    state = state.where((c) => c.item.id != itemId).toList();
  }

  void updateQuantity(int itemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(itemId);
      return;
    }
    state = [
      for (final c in state)
        if (c.item.id == itemId)
          c.copyWith(quantity: newQuantity.clamp(1, c.item.stock))
        else
          c
    ];
  }

  void updateDiscount(int itemId, double discount) {
    state = [
      for (final c in state)
        if (c.item.id == itemId)
          c.copyWith(discount: discount.clamp(0.0, c.subtotal))
        else
          c
    ];
  }

  double get cartTotal => state.fold(0, (sum, c) => sum + c.total);

  void clearCart() => state = [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Selected customer for the current POS session
class SelectedCustomer {
  final int    id;
  final String name;
  final double walletBalance;
  const SelectedCustomer({required this.id, required this.name, required this.walletBalance});
}

final selectedCustomerProvider = StateProvider<SelectedCustomer?>((ref) => null);
