import 'package:isar/isar.dart';
import 'item.dart';

part 'item_entity.g.dart';

@collection
class ItemEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int itemId; // Remote Django ID

  late String name;
  @Index(type: IndexType.value)
  late String brand;
  late String dosageForm;
  late double price;
  late int stock;
  late int lowStockThreshold;
  
  @Index(unique: true, replace: true)
  late String barcode;
  
  DateTime? expiryDate;

  // Conversion methods
  Item toDomain() {
    return Item(
      id: itemId,
      name: name,
      brand: brand,
      dosageForm: dosageForm,
      price: price,
      stock: stock,
      lowStockThreshold: lowStockThreshold,
      barcode: barcode,
      expiryDate: expiryDate,
    );
  }

  static ItemEntity fromDomain(Item item) {
    return ItemEntity()
      ..itemId = item.id
      ..name = item.name
      ..brand = item.brand
      ..dosageForm = item.dosageForm
      ..price = item.price
      ..stock = item.stock
      ..lowStockThreshold = item.lowStockThreshold
      ..barcode = item.barcode
      ..expiryDate = item.expiryDate;
  }
}
