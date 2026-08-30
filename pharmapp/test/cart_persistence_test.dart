import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/features/pos/providers/cart_provider.dart';
import 'package:pharmapp/features/pos/providers/wholesale_cart_provider.dart';
import 'package:pharmapp/shared/models/cart_item.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _item = Item(
  id: 7,
  name: 'Paracetamol 500mg',
  brand: 'Emzor',
  dosageForm: 'Tablet',
  price: 250.0,
  stock: 40,
  lowStockThreshold: 5,
  barcode: '123',
);

void main() {
  // addItem fires HapticFeedback, which needs a binding for its platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a cart survives the reconnect restart', () async {
    SharedPreferences.setMockInitialValues({});
    final cart = CartNotifier();
    cart.addItem(_item);
    cart.updateQuantity(7, 3);
    await Future<void>.delayed(Duration.zero); // let the write land

    // A restart builds a fresh notifier over the same storage.
    final restored = CartNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.length, 1);
    expect(restored.state.single.item.id, 7);
    expect(restored.state.single.quantity, 3);
  });

  test('clearing the cart clears the stored copy', () async {
    SharedPreferences.setMockInitialValues({
      kRetailCartKey: jsonEncode([
        const CartItem(item: _item, quantity: 2, discount: 0).toJson(),
      ]),
    });
    final cart = CartNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(cart.state, isNotEmpty);

    cart.clearCart();
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kRetailCartKey), isNull);
  });

  test('an unreadable stored cart is dropped, not thrown', () async {
    SharedPreferences.setMockInitialValues({kRetailCartKey: 'not json'});
    final cart = CartNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(cart.state, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kRetailCartKey), isNull);
  });

  test('a wholesale cart survives the restart with its fractional quantity',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cart = WsCartNotifier();
    cart.addItem(_item);
    cart.updateQty(7, 2.5);
    await Future<void>.delayed(Duration.zero);

    final restored = WsCartNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.single.id, 7);
    expect(restored.state.single.qty, 2.5);
  });
}
