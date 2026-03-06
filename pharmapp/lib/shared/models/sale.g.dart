// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SaleItemPayloadImpl _$$SaleItemPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$SaleItemPayloadImpl(
      barcode: json['barcode'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );

Map<String, dynamic> _$$SaleItemPayloadImplToJson(
        _$SaleItemPayloadImpl instance) =>
    <String, dynamic>{
      'barcode': instance.barcode,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
    };

_$PaymentPayloadImpl _$$PaymentPayloadImplFromJson(Map<String, dynamic> json) =>
    _$PaymentPayloadImpl(
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      bankTransfer: (json['bankTransfer'] as num?)?.toDouble() ?? 0.0,
      wallet: (json['wallet'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$PaymentPayloadImplToJson(
        _$PaymentPayloadImpl instance) =>
    <String, dynamic>{
      'cash': instance.cash,
      'bankTransfer': instance.bankTransfer,
      'wallet': instance.wallet,
    };

_$CheckoutPayloadImpl _$$CheckoutPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$CheckoutPayloadImpl(
      items: (json['items'] as List<dynamic>)
          .map((e) => SaleItemPayload.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments:
          PaymentPayload.fromJson(json['payments'] as Map<String, dynamic>),
      customerId: json['customerId'] as String?,
      totalAmount: (json['totalAmount'] as num).toDouble(),
    );

Map<String, dynamic> _$$CheckoutPayloadImplToJson(
        _$CheckoutPayloadImpl instance) =>
    <String, dynamic>{
      'items': instance.items,
      'payments': instance.payments,
      'customerId': instance.customerId,
      'totalAmount': instance.totalAmount,
    };
