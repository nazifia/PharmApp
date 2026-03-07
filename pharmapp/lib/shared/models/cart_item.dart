import 'package:freezed_annotation/freezed_annotation.dart';
import 'item.dart';

part 'cart_item.freezed.dart';
part 'cart_item.g.dart';

@freezed
class CartItem with _$CartItem {
  const CartItem._();

  const factory CartItem({
    required Item item,
    required int quantity,
    required double discount,
  }) = _CartItem;

  factory CartItem.fromJson(Map<String, dynamic> json) =>
      _$CartItemFromJson(json);

  double get subtotal => item.price * quantity;
  double get total    => subtotal - discount;
}
