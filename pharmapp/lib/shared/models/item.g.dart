// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ItemImpl _$$ItemImplFromJson(Map<String, dynamic> json) => _$ItemImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      brand: json['brand'] as String,
      dosageForm: json['dosageForm'] as String,
      price: (json['price'] as num).toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num).toInt(),
      lowStockThreshold: (json['lowStockThreshold'] as num).toInt(),
      barcode: json['barcode'] as String,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
    );

Map<String, dynamic> _$$ItemImplToJson(_$ItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'brand': instance.brand,
      'dosageForm': instance.dosageForm,
      'price': instance.price,
      'costPrice': instance.costPrice,
      'stock': instance.stock,
      'lowStockThreshold': instance.lowStockThreshold,
      'barcode': instance.barcode,
      'expiryDate': instance.expiryDate?.toIso8601String(),
    };
