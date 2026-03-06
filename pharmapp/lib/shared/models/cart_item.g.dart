// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CartItemImpl _$$CartItemImplFromJson(Map<String, dynamic> json) =>
    _$CartItemImpl(
      item: Item.fromJson(json['item'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      discount: (json['discount'] as num).toDouble(),
    );

Map<String, dynamic> _$$CartItemImplToJson(_$CartItemImpl instance) =>
    <String, dynamic>{
      'item': instance.item,
      'quantity': instance.quantity,
      'discount': instance.discount,
    };
