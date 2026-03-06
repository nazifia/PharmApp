import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'sale_model.freezed.dart';
part 'sale_model.g.dart';

@freezed
class Sale with _$Sale {
  const factory Sale({
    required int id,
    required int userId,
    required int customerId,
    required double totalAmount,
    required double discountAmount,
    required double taxAmount,
    required double finalAmount,
    required String paymentMethod, // 'cash', 'card', 'wallet', 'split'
    required String paymentStatus, // 'paid', 'pending', 'refunded'
    required bool isWholesale,
    required bool isReturn,
    required String returnReason,
    required DateTime saleDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    required double cashPayment,
    required double cardPayment,
    required double walletPayment,
    required double bankTransferPayment,
    required String? invoiceNumber,
    required String? customerName,
    required String? customerPhone,
    required List<int> itemIds,
    required List<int> quantities,
    required List<double> prices,
  }) = _Sale;

  factory Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);

  // Validation
  bool get isValid =>
    userId >= 0 &&
    customerId >= 0 &&
    totalAmount >= 0 &&
    discountAmount >= 0 &&
    taxAmount >= 0 &&
    finalAmount >= 0 &&
    cashPayment >= 0 &&
    cardPayment >= 0 &&
    walletPayment >= 0 &&
    bankTransferPayment >= 0 &&
    itemIds.isNotEmpty &&
    itemIds.length == quantities.length &&
    itemIds.length == prices.length;

  // Get formatted information
  String get formattedTotalAmount => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(totalAmount);

  String get formattedDiscountAmount => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(discountAmount);

  String get formattedTaxAmount => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(taxAmount);

  String get formattedFinalAmount => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(finalAmount);

  String get formattedSaleDate => DateFormat('dd MMM yyyy hh:mm a').format(saleDate);

  String get formattedCreatedAt => DateFormat('dd MMM yyyy hh:mm a').format(createdAt);

  String get formattedUpdatedAt => DateFormat('dd MMM yyyy hh:mm a').format(updatedAt);

  // Get payment breakdown
  double get totalPayments => cashPayment + cardPayment + walletPayment + bankTransferPayment;

  String get paymentBreakdown {
    final payments = <String>[];
    if (cashPayment > 0) payments.add('Cash: ₹${cashPayment.toStringAsFixed(2)}');
    if (cardPayment > 0) payments.add('Card: ₹${cardPayment.toStringAsFixed(2)}');
    if (walletPayment > 0) payments.add('Wallet: ₹${walletPayment.toStringAsFixed(2)}');
    if (bankTransferPayment > 0) payments.add('Bank: ₹${bankTransferPayment.toStringAsFixed(2)}');
    return payments.join(', ');
  }

  // Get sale type
  String get saleType {
    if (isWholesale) return 'Wholesale Sale';
    if (isReturn) return 'Sale Return';
    return 'Retail Sale';
  }

  // Get sale status
  String get saleStatus {
    if (isReturn) return 'Returned';
    if (paymentStatus == 'pending') return 'Pending Payment';
    if (paymentStatus == 'refunded') return 'Refunded';
    return 'Completed';
  }

  // Get items count
  int get itemsCount => itemIds.length;

  // Get total items quantity
  int get totalQuantity => quantities.fold(0, (sum, qty) => sum + qty);

  // Get average item price
  double get averageItemPrice => totalQuantity > 0 ? finalAmount / totalQuantity : 0;

  // Get profit information
  double get profitAmount => finalAmount - (totalAmount - discountAmount);
  double get profitPercentage => totalAmount > 0 ? (profitAmount / totalAmount) * 100 : 0;

  // Get tax information
  double get effectiveTaxRate => totalAmount > 0 ? (taxAmount / totalAmount) * 100 : 0;

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

  // Get invoice information
  String get invoiceInfo {
    return invoiceNumber != null ? 'Invoice #$invoiceNumber' : 'Invoice Not Generated';
  }

  // Get sale metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'userId': userId,
      'customerId': customerId,
      'totalAmount': totalAmount,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'isWholesale': isWholesale,
      'isReturn': isReturn,
      'itemsCount': itemsCount,
      'totalQuantity': totalQuantity,
      'profitAmount': profitAmount,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Get sale summary
  String get saleSummary {
    return '$saleType | $formattedFinalAmount | $itemsCount items | $customerInfo';
  }

  // Get sale tags
  List<String> get saleTags {
    final tags = <String>[];

    if (isWholesale) tags.add('Wholesale');
    if (isReturn) tags.add('Return');
    if (paymentStatus != 'paid') tags.add(paymentStatus.capitalize());
    if (itemsCount > 10) tags.add('Bulk');

    return tags;
  }

  // Get sale performance metrics
  Map<String, dynamic> get performanceMetrics {
    return {
      'conversionRate': 1.0, // Always 100% for completed sales
      'averageOrderValue': totalAmount,
      'itemsPerOrder': itemsCount.toDouble(),
      'profitMargin': profitPercentage,
    };
  }

  // Get sale analytics
  Map<String, dynamic> get analytics {
    return {
      'dayOfWeek': DateFormat('EEEE').format(saleDate),
      'hourOfDay': DateFormat('HH').format(saleDate),
      'isWeekend': [DateTime.saturday, DateTime.sunday].contains(saleDate.weekday),
      'isPeakHour': [10, 11, 12, 13, 18, 19, 20].contains(int.parse(DateFormat('HH').format(saleDate))),
    };
  }

  // Get sale comparison
  String get comparisonWithAverage {
    // TODO: Implement comparison with average sales
    return 'Above Average';
  }

  // Get refund information
  Map<String, dynamic> get refundInfo {
    if (!isReturn) return {};

    return {
      'reason': returnReason,
      'refundAmount': finalAmount,
      'refundDate': updatedAt,
      'refundMethod': paymentMethod,
    };
  }

  // Get customer loyalty impact
  int get loyaltyPointsEarned {
    if (isReturn) return -50; // Penalty for returns
    if (isWholesale) return totalQuantity * 2;
    return totalQuantity;
  }

  // Get sale complexity
  String get complexity {
    if (itemsCount > 20) return 'Complex';
    if (itemsCount > 10) return 'Moderate';
    return 'Simple';
  }

  // Get payment method details
  String get paymentMethodDetails {
    switch (paymentMethod) {
      case 'split':
        return paymentBreakdown;
      case 'wallet':
        return 'Wallet: ₹${walletPayment.toStringAsFixed(2)}';
      default:
        return '$paymentMethod: ₹${totalPayments.toStringAsFixed(2)}';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}