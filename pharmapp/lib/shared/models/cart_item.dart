import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'cart_item.freezed.dart';
part 'cart_item.g.dart';

@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required int id,
    required int userId,
    required int itemId,
    required int quantity,
    required double unitPrice,
    required double subtotal,
    required double discount,
    required double total,
    required String status, // 'active', 'checked_out', 'cancelled'
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool isWholesale,
    required String? customerPhone,
    required String? customerName,
  }) = _CartItem;

  factory CartItem.fromJson(Map<String, dynamic> json) => _$CartItemFromJson(json);

  // Validation
  bool get isValid =>
    userId >= 0 &&
    itemId >= 0 &&
    quantity > 0 &&
    unitPrice >= 0 &&
    subtotal >= 0 &&
    discount >= 0 &&
    total >= 0 &&
    ['active', 'checked_out', 'cancelled'].contains(status);

  // Get formatted information
  String get formattedQuantity => '$quantity ${getUnit()}';

  String get formattedSubtotal => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(subtotal);

  String get formattedDiscount => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(discount);

  String get formattedTotal => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(total);

  String get formattedCreatedAt => DateFormat('dd MMM yyyy hh:mm a').format(createdAt);

  String get formattedUpdatedAt => DateFormat('dd MMM yyyy hh:mm a').format(updatedAt);

  // Get item type
  String get cartType {
    return isWholesale ? 'Wholesale' : 'Retail';
  }

  // Get customer information
  String get customerInfo {
    if (customerName != null && customerPhone != null) {
      return '$customerName ($customerPhone)';
    } else if (customerName != null) {
      return customerName!;
    } else if (customerPhone != null) {
      return customerPhone!;
    } else {
      return 'Walk-in Customer';
    }
  }

  // Get cart status
  String get cartStatus {
    switch (status) {
      case 'active':
        return 'Active';
      case 'checked_out':
        return 'Checked Out';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // Get cart status color
  Color get statusColor {
    switch (status) {
      case 'active':
        return const Color(0xFF10B981); // Success green
      case 'checked_out':
        return const Color(0xFF3B82F6); // Info blue
      case 'cancelled':
        return const Color(0xFFDC2626); // Error red
      default:
        return Colors.grey;
    }
  }

  // Get cart metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'userId': userId,
      'itemId': itemId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'status': status,
      'isWholesale': isWholesale,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Get cart summary
  String get cartSummary {
    return '$cartType Cart | ${quantity} items | Total: ₹$total';
  }

  // Get unit
  String getUnit() {
    // TODO: Get unit from item (this would require item repository)
    return 'pcs';
  }

  // Calculate total with tax
  double get totalWithTax {
    final taxRate = isWholesale ? 0.05 : 0.12; // 5% wholesale, 12% retail
    return total * (1 + taxRate);
  }

  // Calculate profit
  double get profit {
    // TODO: Get purchase price from item (this would require item repository)
    final purchasePrice = unitPrice * 0.7; // Estimated 30% margin
    return (unitPrice - purchasePrice) * quantity;
  }

  // Get cart tags
  List<String> get cartTags {
    final tags = <String>[];

    if (isWholesale) tags.add('Wholesale');
    if (discount > 0) tags.add('Discounted');
    if (customerName != null || customerPhone != null) tags.add('Registered');

    return tags;
  }

  // Get cart performance metrics
  Map<String, dynamic> get performanceMetrics {
    return {
      'profitMargin': profit / total,
      'discountPercentage': discount / subtotal,
      'taxAmount': totalWithTax - total,
    };
  }

  // Copy with updated values
  CartItem copyWith({
    int? id,
    int? userId,
    int? itemId,
    int? quantity,
    double? unitPrice,
    double? subtotal,
    double? discount,
    double? total,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isWholesale,
    String? customerPhone,
    String? customerName,
  }) {
    return CartItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isWholesale: isWholesale ?? this.isWholesale,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
    );
  }
}
