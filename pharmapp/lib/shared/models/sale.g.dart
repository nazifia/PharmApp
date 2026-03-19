// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SaleItemPayloadImpl _$$SaleItemPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$SaleItemPayloadImpl(
      barcode: json['barcode'] as String,
      itemId: (json['itemId'] as num?)?.toInt(),
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$SaleItemPayloadImplToJson(
        _$SaleItemPayloadImpl instance) =>
    <String, dynamic>{
      'barcode': instance.barcode,
      'itemId': instance.itemId,
      'quantity': instance.quantity,
      'price': instance.price,
      'discount': instance.discount,
    };

_$PaymentPayloadImpl _$$PaymentPayloadImplFromJson(Map<String, dynamic> json) =>
    _$PaymentPayloadImpl(
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      pos: (json['pos'] as num?)?.toDouble() ?? 0.0,
      bankTransfer: (json['bankTransfer'] as num?)?.toDouble() ?? 0.0,
      wallet: (json['wallet'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$PaymentPayloadImplToJson(
        _$PaymentPayloadImpl instance) =>
    <String, dynamic>{
      'cash': instance.cash,
      'pos': instance.pos,
      'bankTransfer': instance.bankTransfer,
      'wallet': instance.wallet,
    };

_$CheckoutPayloadImpl _$$CheckoutPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$CheckoutPayloadImpl(
      items: (json['items'] as List<dynamic>)
          .map((e) => SaleItemPayload.fromJson(e as Map<String, dynamic>))
          .toList(),
      payment:
          PaymentPayload.fromJson(json['payment'] as Map<String, dynamic>),
      customerId: (json['customerId'] as num?)?.toInt(),
      isWholesale: json['isWholesale'] as bool?,
      paymentMethod: json['paymentMethod'] as String?,
      totalAmount: (json['totalAmount'] as num).toDouble(),
    );

Map<String, dynamic> _$$CheckoutPayloadImplToJson(
        _$CheckoutPayloadImpl instance) =>
    <String, dynamic>{
      'items': instance.items,
      'payment': instance.payment,
      'customerId': instance.customerId,
      'isWholesale': instance.isWholesale,
      'paymentMethod': instance.paymentMethod,
      'totalAmount': instance.totalAmount,
    };
