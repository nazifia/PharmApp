import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

@freezed
class Item with _$Item {
  const factory Item({
    required int id,
    required String name,
    required String brand,
    required String dosageForm,
    required double price,
    @Default(0.0) double costPrice,
    @Default(0.0) double markup,
    @Default(0) int branchId,
    required int stock,
    required int lowStockThreshold,
    required String barcode,
    DateTime? expiryDate,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}
