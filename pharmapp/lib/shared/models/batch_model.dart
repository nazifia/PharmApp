import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'batch_model.freezed.dart';
part 'batch_model.g.dart';

@freezed
class Batch with _$Batch {
  const factory Batch({
    required int id,
    required int itemId,
    required String batchNumber,
    required String manufacturer,
    required DateTime manufactureDate,
    required DateTime expiryDate,
    required int quantity,
    required double purchasePrice,
    required double sellingPrice,
    required double wholesalePrice,
    required String storageCondition,
    required bool isExpired,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String? lotNumber,
    required String? origin,
    required Map<String, dynamic>? qualityParameters,
  }) = _Batch;

  factory Batch.fromJson(Map<String, dynamic> json) => _$BatchFromJson(json);

  // Validation
  bool get isValid =>
    itemId >= 0 &&
    batchNumber.isNotEmpty &&
    manufacturer.isNotEmpty &&
    manufactureDate != null &&
    expiryDate != null &&
    quantity > 0 &&
    purchasePrice >= 0 &&
    sellingPrice >= 0 &&
    wholesalePrice >= 0 &&
    ['room temperature', 'refrigerated', 'frozen'].contains(storageCondition.toLowerCase());

  // Get formatted information
  String get formattedManufactureDate => DateFormat('dd MMM yyyy').format(manufactureDate);

  String get formattedExpiryDate => DateFormat('dd MMM yyyy').format(expiryDate);

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

  // Get batch status
  String get batchStatus {
    if (isExpired) return 'Expired';
    if (expiryDate.difference(DateTime.now()).inDays <= 30) return 'Expiring Soon';
    return 'Active';
  }

  // Get batch status color
  Color get statusColor {
    if (isExpired) return const Color(0xFFDC2626); // Error red
    if (expiryDate.difference(DateTime.now()).inDays <= 30) return const Color(0xFFF59E0B); // Warning amber
    return const Color(0xFF10B981); // Success green
  }

  // Get batch metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'itemId': itemId,
      'batchNumber': batchNumber,
      'manufacturer': manufacturer,
      'manufactureDate': manufactureDate.millisecondsSinceEpoch,
      'expiryDate': expiryDate.millisecondsSinceEpoch,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'wholesalePrice': wholesalePrice,
      'storageCondition': storageCondition,
      'isExpired': isExpired,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lotNumber': lotNumber,
      'origin': origin,
      'qualityParameters': qualityParameters,
    };
  }

  // Get batch summary
  String get batchSummary {
    return 'Batch $batchNumber | $quantity pcs | Exp: ${formattedExpiryDate}';
  }

  // Get batch age
  String get batchAge {
    final daysSinceManufacture = DateTime.now().difference(manufactureDate).inDays;
    return '$daysSinceManufacture days old';
  }

  // Get shelf life
  String get shelfLife {
    final daysToExpiry = expiryDate.difference(DateTime.now()).inDays;
    return '$daysToExpiry days remaining';
  }

  // Get storage recommendations
  String get storageRecommendation {
    switch (storageCondition.toLowerCase()) {
      case 'refrigerated':
        return 'Store in refrigerator at 2-8°C';
      case 'frozen':
        return 'Store in freezer at -20°C';
      case 'room temperature':
        return 'Store at room temperature below 25°C';
      default:
        return 'Follow storage instructions';
    }
  }

  // Get batch quality
  String get qualityInfo {
    if (qualityParameters != null) {
      final potency = qualityParameters!['potency'] ?? 'N/A';
      final purity = qualityParameters!['purity'] ?? 'N/A';
      final dissolution = qualityParameters!['dissolution'] ?? 'N/A';
      return 'Potency: $potency | Purity: $purity | Dissolution: $dissolution';
    } else {
      return 'Quality parameters not available';
    }
  }

  // Get batch tags
  List<String> get batchTags {
    final tags = <String>[];

    if (isExpired) tags.add('Expired');
    if (expiryDate.difference(DateTime.now()).inDays <= 30) tags.add('Expiring Soon');
    if (qualityParameters != null) tags.add('Quality Checked');

    return tags;
  }

  // Get batch performance metrics
  Map<String, dynamic> get performanceMetrics {
    return {
      'shelfLife': expiryDate.difference(manufactureDate).inDays,
      'daysToExpiry': expiryDate.difference(DateTime.now()).inDays,
      'priceDifference': sellingPrice - purchasePrice,
      'profitMargin': (sellingPrice - purchasePrice) / purchasePrice,
    };
  }

  // Get batch comparison
  String get comparisonWithOtherBatches {
    // TODO: Compare with other batches of same item
    return 'Average';
  }

  // Check if batch is close to expiry
  bool get isCloseToExpiry {
    return expiryDate.difference(DateTime.now()).inDays <= 90; // 3 months
  }

  // Get batch origin information
  String get originInfo {
    if (origin != null) {
      return 'Origin: $origin';
    } else {
      return 'Origin: Unknown';
    }
  }

  // Copy with updated values
  Batch copyWith({
    int? id,
    int? itemId,
    String? batchNumber,
    String? manufacturer,
    DateTime? manufactureDate,
    DateTime? expiryDate,
    int? quantity,
    double? purchasePrice,
    double? sellingPrice,
    double? wholesalePrice,
    String? storageCondition,
    bool? isExpired,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lotNumber,
    String? origin,
    Map<String, dynamic>? qualityParameters,
  }) {
    return Batch(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      batchNumber: batchNumber ?? this.batchNumber,
      manufacturer: manufacturer ?? this.manufacturer,
      manufactureDate: manufactureDate ?? this.manufactureDate,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      storageCondition: storageCondition ?? this.storageCondition,
      isExpired: isExpired ?? this.isExpired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lotNumber: lotNumber ?? this.lotNumber,
      origin: origin ?? this.origin,
      qualityParameters: qualityParameters ?? this.qualityParameters,
    );
  }
}