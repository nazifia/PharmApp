import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'item_model.freezed.dart';
part 'item_model.g.dart';

@freezed
class Item with _$Item {
  const factory Item({
    required int id,
    required String name,
    required String brand,
    required String dosageForm,
    required String genericName,
    required String manufacturer,
    required String category,
    required String subCategory,
    required double purchasePrice,
    required double sellingPrice,
    required double wholesalePrice,
    required int stock,
    required int lowStockThreshold,
    required int reorderLevel,
    required bool isPrescriptionRequired,
    required DateTime? expiryDate,
    required DateTime? manufactureDate,
    required String barcode,
    required String batchNumber,
    required String storageCondition,
    required bool isDiscountable,
    required double discountPercentage,
    required String unit,
    required String packageSize,
    required String packageUnit,
    required bool isTaxable,
    required double taxRate,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<String> tags,
    required List<String> alternativeBrands,
    required String? imageUrl,
    required String? description,
    required bool isFeatured,
    required bool isPopular,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

  // Validation
  bool get isValid =>
    name.isNotEmpty &&
    brand.isNotEmpty &&
    dosageForm.isNotEmpty &&
    genericName.isNotEmpty &&
    manufacturer.isNotEmpty &&
    category.isNotEmpty &&
    subCategory.isNotEmpty &&
    purchasePrice >= 0 &&
    sellingPrice >= 0 &&
    wholesalePrice >= 0 &&
    stock >= 0 &&
    lowStockThreshold >= 0 &&
    reorderLevel >= 0 &&
    discountPercentage >= 0 &&
    discountPercentage <= 100 &&
    taxRate >= 0 &&
    taxRate <= 100;

  // Get formatted prices
  String get formattedPurchasePrice => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(purchasePrice);

  String get formattedSellingPrice => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(sellingPrice);

  String get formattedWholesalePrice => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(wholesalePrice);

  // Get profit margins
  double get profitMargin => sellingPrice - purchasePrice;
  double get profitPercentage => (profitMargin / purchasePrice) * 100;

  double get wholesaleProfitMargin => wholesalePrice - purchasePrice;
  double get wholesaleProfitPercentage => (wholesaleProfitMargin / purchasePrice) * 100;

  // Get stock status
  bool get isLowStock => stock <= lowStockThreshold;
  bool get needsReorder => stock <= reorderLevel;
  bool get isExpiredItem => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  // Get discount information
  double get discountedPrice => sellingPrice - (sellingPrice * (discountPercentage / 100));
  String get discountText => '${discountPercentage.toInt()}% off';

  // Get tax information
  double get taxAmount => sellingPrice * (taxRate / 100);
  double get priceWithTax => sellingPrice + taxAmount;

  // Get formatted dates
  String get formattedExpiryDate => expiryDate != null
    ? DateFormat('dd MMM yyyy').format(expiryDate!)
    : 'N/A';

  String get formattedManufactureDate => manufactureDate != null
    ? DateFormat('dd MMM yyyy').format(manufactureDate!)
    : 'N/A';

  // Get storage recommendations
  String get storageRecommendation {
    switch (storageCondition.toLowerCase()) {
      case 'refrigerated':
        return 'Store in refrigerator at 2-8°C';
      case 'room temperature':
        return 'Store at room temperature below 25°C';
      case 'cool dry place':
        return 'Store in cool, dry place away from sunlight';
      case 'freeze':
        return 'Store in freezer at -20°C';
      default:
        return 'Follow storage instructions on label';
    }
  }

  // Get item availability
  String get availabilityStatus {
    if (isExpiredItem) return 'Expired';
    if (isLowStock) return 'Low Stock';
    if (stock == 0) return 'Out of Stock';
    return 'In Stock';
  }

  // Get item type
  String get itemType {
    if (isPrescriptionRequired) return 'Prescription';
    if (isFeatured) return 'Featured';
    if (isPopular) return 'Popular';
    return 'Regular';
  }

  // Get item tags
  List<String> get itemTags {
    final tagsList = <String>[];

    if (isPrescriptionRequired) tagsList.add('Prescription');
    if (isFeatured) tagsList.add('Featured');
    if (isPopular) tagsList.add('Popular');
    if (isLowStock) tagsList.add('Low Stock');
    if (isExpiredItem) tagsList.add('Expired');
    if (needsReorder) tagsList.add('Reorder');

    return tagsList.isNotEmpty ? tagsList : ['Regular'];
  }

  // Get item image URL
  String get itemImageUrl {
    return imageUrl ?? 'https://via.placeholder.com/300x300?text=$brand+$name';
  }

  // Calculate total value
  double get totalStockValue => stock * sellingPrice;
  double get totalPurchaseValue => stock * purchasePrice;

  // Get price comparison
  String get priceComparison {
    if (sellingPrice > wholesalePrice) {
      return 'Retail price higher than wholesale';
    } else if (sellingPrice < wholesalePrice) {
      return 'Wholesale price higher than retail';
    } else {
      return 'Prices are equal';
    }
  }

  // Get discount savings
  double get discountSavings => sellingPrice * (discountPercentage / 100);
  String get savingsText => '₹${discountSavings.toStringAsFixed(2)} saved';

  // Get item description
  String get itemDescription {
    return description ??
      '$brand $name is a $dosageForm containing $genericName. ';
  }

  // Get alternative brands
  String get alternativeBrandsText {
    if (alternativeBrands.isEmpty) return 'No alternatives available';
    return 'Alternatives: ${alternativeBrands.take(3).join(', ')}';
  }

  // Get item metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'stock': stock,
      'price': sellingPrice,
      'isLowStock': isLowStock,
      'isExpired': isExpiredItem,
      'profitMargin': profitMargin,
    };
  }
}