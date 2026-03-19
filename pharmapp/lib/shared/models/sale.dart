import 'package:freezed_annotation/freezed_annotation.dart';

part 'sale.freezed.dart';
part 'sale.g.dart';

@freezed
class SaleItemPayload with _$SaleItemPayload {
  const factory SaleItemPayload({
    required String barcode,
    required int? itemId,
    required int quantity,
    required double price,
    @Default(0.0) double discount,
  }) = _SaleItemPayload;

  factory SaleItemPayload.fromJson(Map<String, dynamic> json) => _$SaleItemPayloadFromJson(json);
}

@freezed
class PaymentPayload with _$PaymentPayload {
  const factory PaymentPayload({
    @Default(0.0) double cash,
    @Default(0.0) double pos,
    @Default(0.0) double bankTransfer,
    @Default(0.0) double wallet,
  }) = _PaymentPayload;

  factory PaymentPayload.fromJson(Map<String, dynamic> json) => _$PaymentPayloadFromJson(json);
}

@freezed
class CheckoutPayload with _$CheckoutPayload {
  const factory CheckoutPayload({
    required List<SaleItemPayload> items,
    required PaymentPayload payment,
    int? customerId,
    bool? isWholesale,
    String? paymentMethod,
    required double totalAmount,
  }) = _CheckoutPayload;

  factory CheckoutPayload.fromJson(Map<String, dynamic> json) => _$CheckoutPayloadFromJson(json);
}
