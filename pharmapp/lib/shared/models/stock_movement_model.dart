import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'stock_movement_model.freezed.dart';
part 'stock_movement_model.g.dart';

@freezed
class StockMovement with _$StockMovement {
  const factory StockMovement({
    required int id,
    required int itemId,
    required int batchId,
    required int quantity,
    required double unitCost,
    required String movementType, // 'inward', 'outward', 'adjustment', 'return'
    required String referenceType, // 'purchase', 'sale', 'transfer', 'damage', 'expiry'
    required String referenceId,
    required String notes,
    required int userId,
    required DateTime movementDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String? supplierName,
    required String? customerName,
    required String? fromLocation,
    required String? toLocation,
    required String? reason,
  }) = _StockMovement;

  factory StockMovement.fromJson(Map<String, dynamic> json) => _$StockMovementFromJson(json);

  // Validation
  bool get isValid =>
    itemId >= 0 &&
    batchId >= 0 &&
    quantity != 0 && // Quantity can be negative for outward movements
    unitCost >= 0 &&
    ['inward', 'outward', 'adjustment', 'return'].contains(movementType) &&
    [
      'purchase',
      'sale',
      'transfer',
      'damage',
      'expiry',
      'adjustment',
      'return',
      'sample',
      'donation'
    ].contains(referenceType) &&
    referenceId.isNotEmpty &&
    notes.isNotEmpty &&
    userId >= 0 &&
    movementDate != null;

  // Get formatted information
  String get formattedMovementDate => DateFormat('dd MMM yyyy hh:mm a').format(movementDate);

  String get formattedCreatedAt => DateFormat('dd MMM yyyy hh:mm a').format(createdAt);

  String get formattedUpdatedAt => DateFormat('dd MMM yyyy hh:mm a').format(updatedAt);

  String get formattedUnitCost => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(unitCost);

  String get formattedTotalCost => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(unitCost * quantity);

  // Get movement type
  String get movementTypeDisplay {
    switch (movementType) {
      case 'inward':
        return 'Inward';
      case 'outward':
        return 'Outward';
      case 'adjustment':
        return 'Adjustment';
      case 'return':
        return 'Return';
      default:
        return 'Movement';
    }
  }

  // Get movement type color
  Color get movementTypeColor {
    switch (movementType) {
      case 'inward':
        return const Color(0xFF10B981); // Success green
      case 'outward':
        return const Color(0xFFDC2626); // Error red
      case 'adjustment':
        return const Color(0xFFF59E0B); // Warning amber
      case 'return':
        return const Color(0xFF3B82F6); // Info blue
      default:
        return Colors.grey;
    }
  }

  // Get reference type
  String get referenceTypeDisplay {
    switch (referenceType) {
      case 'purchase':
        return 'Purchase';
      case 'sale':
        return 'Sale';
      case 'transfer':
        return 'Transfer';
      case 'damage':
        return 'Damage';
      case 'expiry':
        return 'Expiry';
      case 'adjustment':
        return 'Adjustment';
      case 'return':
        return 'Return';
      case 'sample':
        return 'Sample';
      case 'donation':
        return 'Donation';
      default:
        return referenceType.capitalize();
    }
  }

  // Get reference type color
  Color get referenceTypeColor {
    switch (referenceType) {
      case 'purchase':
        return const Color(0xFF10B981); // Success green
      case 'sale':
        return const Color(0xFF3B82F6); // Info blue
      case 'transfer':
        return const Color(0xFFF59E0B); // Warning amber
      case 'damage':
      case 'expiry':
        return const Color(0xFFDC2626); // Error red
      default:
        return Colors.grey;
    }
  }

  // Get movement direction
  String get movementDirection {
    return quantity > 0 ? 'Inward' : 'Outward';
  }

  // Get movement direction icon
  IconData get movementDirectionIcon {
    return quantity > 0 ? Icons.arrow_downward : Icons.arrow_upward;
  }

  // Get movement metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'itemId': itemId,
      'batchId': batchId,
      'quantity': quantity,
      'unitCost': unitCost,
      'movementType': movementType,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'notes': notes,
      'userId': userId,
      'movementDate': movementDate.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'supplierName': supplierName,
      'customerName': customerName,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'reason': reason,
    };
  }

  // Get movement summary
  String get movementSummary {
    return '$movementTypeDisplay | ${quantity.abs()} units | $referenceTypeDisplay';
  }

  // Get movement details
  String get movementDetails {
    return 'User: $userId | Date: ${formattedMovementDate} | Cost: ₹${(unitCost * quantity).toStringAsFixed(2)}';
  }

  // Get involved parties
  String get involvedParties {
    if (supplierName != null && customerName != null) {
      return 'Supplier: $supplierName | Customer: $customerName';
    } else if (supplierName != null) {
      return 'Supplier: $supplierName';
    } else if (customerName != null) {
      return 'Customer: $customerName';
    } else {
      return 'No parties involved';
    }
  }

  // Get location information
  String get locationInfo {
    if (fromLocation != null && toLocation != null) {
      return 'From: $fromLocation | To: $toLocation';
    } else if (fromLocation != null) {
      return 'From: $fromLocation';
    } else if (toLocation != null) {
      return 'To: $toLocation';
    } else {
      return 'Location: Unknown';
    }
  }

  // Get reason information
  String get reasonInfo {
    if (reason != null) {
      return 'Reason: $reason';
    } else {
      return 'No reason provided';
    }
  }

  // Get movement tags
  List<String> get movementTags {
    final tags = <String>[];

    if (movementType == 'inward') tags.add('Inward');
    if (movementType == 'outward') tags.add('Outward');
    if (movementType == 'adjustment') tags.add('Adjustment');
    if (referenceType == 'damage') tags.add('Damage');
    if (referenceType == 'expiry') tags.add('Expiry');
    if (supplierName != null) tags.add('Supplier');
    if (customerName != null) tags.add('Customer');

    return tags;
  }

  // Get movement performance metrics
  Map<String, dynamic> get performanceMetrics {
    return {
      'quantity': quantity,
      'totalCost': unitCost * quantity,
      'costPerUnit': unitCost,
      'daysSinceMovement': DateTime.now().difference(movementDate).inDays,
    };
  }

  // Get movement impact
  String get impact {
    if (quantity > 0) {
      return 'Increased stock by ${quantity.abs()} units';
    } else {
      return 'Decreased stock by ${quantity.abs()} units';
    }
  }

  // Check if movement is significant
  bool get isSignificant {
    return quantity.abs() >= 100; // More than 100 units
  }

  // Get movement type icon
  IconData get movementTypeIcon {
    switch (movementType) {
      case 'inward':
        return Icons.add_circle;
      case 'outward':
        return Icons.remove_circle;
      case 'adjustment':
        return Icons.edit;
      case 'return':
        return Icons.reply;
      default:
        return Icons.swap_horiz;
    }
  }

  // Copy with updated values
  StockMovement copyWith({
    int? id,
    int? itemId,
    int? batchId,
    int? quantity,
    double? unitCost,
    String? movementType,
    String? referenceType,
    String? referenceId,
    String? notes,
    int? userId,
    DateTime? movementDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? customerName,
    String? fromLocation,
    String? toLocation,
    String? reason,
  }) {
    return StockMovement(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      batchId: batchId ?? this.batchId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      movementType: movementType ?? this.movementType,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      movementDate: movementDate ?? this.movementDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      customerName: customerName ?? this.customerName,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      reason: reason ?? this.reason,
    );
  }
}