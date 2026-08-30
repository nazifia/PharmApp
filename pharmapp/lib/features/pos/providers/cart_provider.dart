import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/item.dart';

/// Where the in-progress retail cart is kept between runs.
/// Cleared on logout so a shared terminal never hands one cashier's cart to
/// the next — see AuthService.logout().
const kRetailCartKey = 'cart_retail';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    _restore();
  }

  /// A reconnect reloads the web page (and restarts the native app), which
  /// would otherwise throw away a cart the cashier is halfway through ringing
  /// up. Persisting every change also survives an accidental tab close.
  @override
  set state(List<CartItem> value) {
    super.state = value;
    _persist(value);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kRetailCartKey);
    // Anything added while this was loading wins — never clobber a live cart.
    if (raw == null || state.isNotEmpty) return;
    try {
      super.state = (jsonDecode(raw) as List)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await prefs.remove(kRetailCartKey); // unreadable (model changed) — drop it
    }
  }

  void _persist(List<CartItem> items) {
    SharedPreferences.getInstance().then((prefs) {
      if (items.isEmpty) return prefs.remove(kRetailCartKey);
      return prefs.setString(
          kRetailCartKey, jsonEncode(items.map((c) => c.toJson()).toList()));
    }).ignore();
  }

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
    HapticFeedback.selectionClick(); // confirm item landed in cart
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

  double get cartTotal => state.fold(0.0, (sum, c) => sum + c.total);

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
  final String? hmoProvider;
  final String? hmoCardNumber;
  final double? hmoCoveragePercent;
  const SelectedCustomer({
    required this.id,
    required this.name,
    required this.walletBalance,
    this.hmoProvider,
    this.hmoCardNumber,
    this.hmoCoveragePercent,
  });

  bool get hasHmo => hmoCardNumber != null && hmoCardNumber!.isNotEmpty;
  double hmoAmount(double total) => hasHmo ? total * (hmoCoveragePercent ?? 0) / 100 : 0.0;
  double patientAmount(double total) => total - hmoAmount(total);
}

final selectedCustomerProvider = StateProvider<SelectedCustomer?>((ref) => null);

/// Tracks which cart items originated from prescriptions so that a completed
/// POS checkout can auto-dispense those medication slots.
/// Key = prescription ID, Value = list of 0-based medication indices in that prescription.
final prescriptionCartBindingsProvider = StateProvider<Map<int, List<int>>>((ref) => {});

/// Consultation fee owed for prescriptions whose medications are in the cart.
/// Key = prescription ID, Value = consultation fee amount. Summed once per
/// prescription at checkout and added to the sale total as a silent surcharge
/// (never itemised on the receipt). Cleared after a completed checkout.
final prescriptionConsultationFeesProvider =
    StateProvider<Map<int, double>>((ref) => {});
