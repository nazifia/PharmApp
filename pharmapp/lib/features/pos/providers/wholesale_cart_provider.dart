import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/item.dart';

/// Where the in-progress wholesale cart is kept between runs.
/// Cleared on logout — see AuthService.logout().
const kWholesaleCartKey = 'cart_wholesale';

class WsCartLine {
  final int    id;
  final String name;
  final double price;
  final double qty;
  final String barcode;
  final double discount;
  final int    stock;
  final String unitOfDispensing;

  const WsCartLine({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.barcode,
    this.discount = 0,
    this.stock = 9999,
    this.unitOfDispensing = '',
  });

  double get total => (price * qty) - discount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'qty': qty,
        'barcode': barcode,
        'discount': discount,
        'stock': stock,
        'unitOfDispensing': unitOfDispensing,
      };

  factory WsCartLine.fromJson(Map<String, dynamic> j) => WsCartLine(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        qty: (j['qty'] as num).toDouble(),
        barcode: j['barcode'] as String? ?? '',
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        stock: (j['stock'] as num?)?.toInt() ?? 9999,
        unitOfDispensing: j['unitOfDispensing'] as String? ?? '',
      );

  WsCartLine copyWith({double? qty, double? discount}) => WsCartLine(
    id: id, name: name, price: price, barcode: barcode, stock: stock,
    unitOfDispensing: unitOfDispensing,
    qty: qty ?? this.qty,
    discount: discount ?? this.discount,
  );
}

class WsCartNotifier extends StateNotifier<List<WsCartLine>> {
  WsCartNotifier() : super([]) {
    _restore();
  }

  /// A reconnect reloads the web page (and restarts the native app), which
  /// would otherwise throw away a cart being rung up. Persisting every change
  /// also survives an accidental tab close.
  @override
  set state(List<WsCartLine> value) {
    super.state = value;
    _persist(value);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kWholesaleCartKey);
    // Anything added while this was loading wins — never clobber a live cart.
    if (raw == null || state.isNotEmpty) return;
    try {
      super.state = (jsonDecode(raw) as List)
          .map((e) => WsCartLine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await prefs.remove(kWholesaleCartKey); // unreadable — drop it
    }
  }

  void _persist(List<WsCartLine> lines) {
    SharedPreferences.getInstance().then((prefs) {
      if (lines.isEmpty) return prefs.remove(kWholesaleCartKey);
      return prefs.setString(
          kWholesaleCartKey, jsonEncode(lines.map((l) => l.toJson()).toList()));
    }).ignore();
  }

  void addItem(Item item) {
    if (item.stock == 0) return;
    final idx = state.indexWhere((l) => l.id == item.id);
    if (idx >= 0) {
      if (state[idx].qty >= state[idx].stock) return;
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(qty: state[i].qty + 1.0) else state[i]
      ];
    } else {
      state = [
        ...state,
        WsCartLine(
          id: item.id, name: item.name, price: item.price,
          qty: 1.0, barcode: item.barcode, stock: item.stock,
          unitOfDispensing: item.unitOfDispensing,
        ),
      ];
    }
    HapticFeedback.selectionClick(); // confirm item landed in cart
  }

  void addItemWithQty(Item item, double qty) {
    if (item.stock == 0) return;
    final idx = state.indexWhere((l) => l.id == item.id);
    if (idx >= 0) {
      final newQty = (state[idx].qty + qty).clamp(0.5, state[idx].stock.toDouble());
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(qty: newQty) else state[i]
      ];
    } else {
      final clamped = qty.clamp(0.5, item.stock.toDouble());
      state = [
        ...state,
        WsCartLine(
          id: item.id, name: item.name, price: item.price,
          qty: clamped, barcode: item.barcode, stock: item.stock,
          unitOfDispensing: item.unitOfDispensing,
        ),
      ];
    }
    HapticFeedback.selectionClick(); // confirm item landed in cart
  }

  void removeItem(int id) => state = state.where((l) => l.id != id).toList();

  void updateQty(int id, double qty) {
    if (qty < 0.5) { removeItem(id); return; }
    state = [
      for (final l in state)
        if (l.id == id) l.copyWith(qty: qty.clamp(0.5, l.stock.toDouble())) else l
    ];
  }

  void updateDiscount(int id, double discount) {
    state = [
      for (final l in state)
        if (l.id == id) l.copyWith(discount: discount.clamp(0.0, l.price * l.qty)) else l
    ];
  }

  void clearCart() => state = [];

  double get cartTotal => state.fold(0.0, (s, l) => s + l.total);
  double get cartCount => state.fold(0.0, (s, l) => s + l.qty);
}

final wsCartProvider = StateNotifierProvider<WsCartNotifier, List<WsCartLine>>(
  (ref) => WsCartNotifier(),
);

class WsSelectedCustomer {
  final int    id;
  final String name;
  final double walletBalance;
  const WsSelectedCustomer({
    required this.id,
    required this.name,
    required this.walletBalance,
  });
}

final wsSelectedCustomerProvider = StateProvider<WsSelectedCustomer?>((ref) => null);

String fmtWsQty(double q) =>
    q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
