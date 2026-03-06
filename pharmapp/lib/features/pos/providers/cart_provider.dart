import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Item item) {
    final existingIndex = state.indexWhere((c) => c.item.id == item.id);
    if (existingIndex >= 0) {
      // Increment quantity
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

  void updateQuantity(int itemId, int newQuantity) {
    if (newQuantity <= 0) {
       state = state.where((c) => c.item.id != itemId).toList();
       return;
    }
    state = [
      for (final cartItem in state)
        if (cartItem.item.id == itemId)
          cartItem.copyWith(quantity: newQuantity)
        else
          cartItem
    ];
  }

  double get cartTotal => state.fold(0, (total, current) => total + current.subtotal);

  void clearCart() {
    state = [];
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
