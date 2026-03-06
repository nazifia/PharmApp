import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'payment_model.freezed.dart';
part 'payment_model.g.dart';

@freezed
class Payment with _$Payment {
  const factory Payment({
    required int id,
    required int saleId,
    required String paymentMethod, // 'cash', 'card', 'wallet', 'bank_transfer', 'split'
    required double amount,
    required String status, // 'pending', 'completed', 'failed', 'refunded'
    required DateTime paymentDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String? transactionId,
    required String? paymentGateway,
    required String? cardType,
    required String? cardLastFour,
    required String? bankName,
    required String? referenceNumber,
    required String? notes,
  }) = _Payment;

  factory Payment.fromJson(Map<String, dynamic> json) => _$PaymentFromJson(json);

  // Validation
  bool get isValid =>
    saleId >= 0 &&
    ['cash', 'card', 'wallet', 'bank_transfer', 'split'].contains(paymentMethod) &&
    amount >= 0 &&
    ['pending', 'completed', 'failed', 'refunded'].contains(status);

  // Get formatted information
  String get formattedAmount => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(amount);

  String get formattedPaymentDate => DateFormat('dd MMM yyyy hh:mm a').format(paymentDate);

  String get formattedCreatedAt => DateFormat('dd MMM yyyy hh:mm a').format(createdAt);

  String get formattedUpdatedAt => DateFormat('dd MMM yyyy hh:mm a').format(updatedAt);

  // Get payment type
  String get paymentType {
    switch (paymentMethod) {
      case 'cash':
        return 'Cash Payment';
      case 'card':
        return 'Card Payment';
      case 'wallet':
        return 'Wallet Payment';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'split':
        return 'Split Payment';
      default:
        return 'Payment';
    }
  }

  // Get payment status
  String get paymentStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  // Get payment status color
  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B); // Warning amber
      case 'completed':
        return const Color(0xFF10B981); // Success green
      case 'failed':
        return const Color(0xFFDC2626); // Error red
      case 'refunded':
        return const Color(0xFF9CA3AF); // Gray
      default:
        return Colors.grey;
    }
  }

  // Get payment method details
  String get methodDetails {
    switch (paymentMethod) {
      case 'card':
        return 'Card ending in $cardLastFour';
      case 'bank_transfer':
        return 'Bank: $bankName';
      case 'wallet':
        return 'Wallet balance';
      case 'split':
        return 'Multiple methods';
      default:
        return paymentMethod.capitalize();
    }
  }

  // Get payment metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'saleId': saleId,
      'paymentMethod': paymentMethod,
      'amount': amount,
      'status': status,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'transactionId': transactionId,
      'paymentGateway': paymentGateway,
      'cardType': cardType,
      'cardLastFour': cardLastFour,
      'bankName': bankName,
      'referenceNumber': referenceNumber,
      'notes': notes,
    };
  }

  // Get payment summary
  String get paymentSummary {
    return '$paymentType | $formattedAmount | $paymentStatus';
  }

  // Get transaction information
  String get transactionInfo {
    if (transactionId != null) {
      return 'Transaction ID: $transactionId';
    } else if (referenceNumber != null) {
      return 'Reference: $referenceNumber';
    } else {
      return 'Manual Payment';
    }
  }

  // Get gateway information
  String get gatewayInfo {
    if (paymentGateway != null) {
      return 'Gateway: $paymentGateway';
    } else {
      return 'Manual';
    }
  }

  // Get card information
  String get cardInfo {
    if (cardType != null && cardLastFour != null) {
      return '$cardType ending in $cardLastFour';
    } else if (cardType != null) {
      return cardType;
    } else {
      return 'Card Payment';
    }
  }

  // Get bank information
  String get bankInfo {
    if (bankName != null) {
      return 'Bank: $bankName';
    } else {
      return 'Bank Transfer';
    }
  }

  // Get payment tags
  List<String> get paymentTags {
    final tags = <String>[];

    if (status == 'pending') tags.add('Pending');
    if (status == 'failed') tags.add('Failed');
    if (status == 'refunded') tags.add('Refunded');
    if (paymentMethod == 'split') tags.add('Split');
    if (paymentGateway != null) tags.add('Online');

    return tags;
  }

  // Get payment performance metrics
  Map<String, dynamic> get performanceMetrics {
    return {
      'successRate': status == 'completed' ? 1.0 : 0.0,
      'processingTime': (updatedAt.millisecondsSinceEpoch - createdAt.millisecondsSinceEpoch) / 1000,
    };
  }

  // Copy with updated values
  Payment copyWith({
    int? id,
    int? saleId,
    String? paymentMethod,
    double? amount,
    String? status,
    DateTime? paymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? transactionId,
    String? paymentGateway,
    String? cardType,
    String? cardLastFour,
    String? bankName,
    String? referenceNumber,
    String? notes,
  }) {
    return Payment(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactionId: transactionId ?? this.transactionId,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      cardType: cardType ?? this.cardType,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      bankName: bankName ?? this.bankName,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}