import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'customer_model.freezed.dart';
part 'customer_model.g.dart';

@freezed
class Customer with _$Customer {
  const factory Customer({
    required int id,
    required String name,
    required String phoneNumber,
    required String? email,
    required String? address,
    required double walletBalance,
    required bool isWholesaleCustomer,
    required int loyaltyPoints,
    required int totalPurchases,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);

  // Validation
  bool get isValid =>
    name.isNotEmpty &&
    phoneNumber.isNotEmpty &&
    phoneNumber.length >= 10 &&
    walletBalance >= 0 &&
    loyaltyPoints >= 0 &&
    totalPurchases >= 0;

  // Get formatted information
  String get formattedWalletBalance => NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  ).format(walletBalance);

  String get formattedLoyaltyPoints => '${loyaltyPoints} pts';

  String get formattedTotalPurchases => '₹${totalPurchases.toStringAsFixed(2)}';

  String get formattedCreatedAt => DateFormat('dd MMM yyyy').format(createdAt);

  String get formattedUpdatedAt => DateFormat('dd MMM yyyy').format(updatedAt);

  // Get customer type
  String get customerType {
    if (isWholesaleCustomer) return 'Wholesale Customer';
    if (loyaltyPoints >= 1000) return 'Gold Member';
    if (loyaltyPoints >= 500) return 'Silver Member';
    if (loyaltyPoints >= 100) return 'Bronze Member';
    return 'Regular Customer';
  }

  // Get membership tier
  String get membershipTier {
    if (loyaltyPoints >= 1000) return 'Gold';
    if (loyaltyPoints >= 500) return 'Silver';
    if (loyaltyPoints >= 100) return 'Bronze';
    return 'None';
  }

  // Get customer status
  String get customerStatus {
    if (walletBalance > 1000) return 'Premium';
    if (walletBalance > 500) return 'Regular';
    if (walletBalance > 0) return 'Basic';
    return 'New';
  }

  // Get discount eligibility
  double get discountEligibility {
    switch (membershipTier) {
      case 'Gold':
        return 15.0;
      case 'Silver':
        return 10.0;
      case 'Bronze':
        return 5.0;
      default:
        return 0.0;
    }
  }

  // Get customer benefits
  List<String> get customerBenefits {
    final benefits = <String>[];

    if (isWholesaleCustomer) benefits.add('Wholesale Pricing');
    if (loyaltyPoints >= 100) benefits.add('Loyalty Points');
    if (walletBalance > 0) benefits.add('Wallet Balance');
    if (membershipTier != 'None') benefits.add('$membershipTier Member');

    return benefits;
  }

  // Get customer metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'name': name,
      'phone': phoneNumber,
      'email': email,
      'wallet': walletBalance,
      'points': loyaltyPoints,
      'totalPurchases': totalPurchases,
      'type': customerType,
      'tier': membershipTier,
    };
  }

  // Get customer summary
  String get customerSummary {
    return '$name - $customerType | Wallet: $formattedWalletBalance | Points: $loyaltyPoints';
  }

  // Get customer avatar
  String get customerAvatar {
    final initials = name.split(' ').map((word) => word[0]).join();
    return 'https://ui-avatars.com/api/?name=$initials&size=128&background=0D9488&color=ffffff';
  }

  // Calculate loyalty points for purchase
  int calculateLoyaltyPoints(double purchaseAmount) {
    final basePoints = purchaseAmount.toInt();
    final bonusPoints = isWholesaleCustomer ? basePoints * 2 : basePoints;
    return basePoints + bonusPoints;
  }

  // Update wallet balance
  Customer updateWalletBalance(double amount, {bool isCredit = true}) {
    final newBalance = isCredit ? walletBalance + amount : walletBalance - amount;
    return copyWith(walletBalance: newBalance.clamp(0, double.infinity));
  }

  // Update loyalty points
  Customer updateLoyaltyPoints(int points, {bool isAddition = true}) {
    final newPoints = isAddition ? loyaltyPoints + points : loyaltyPoints - points;
    return copyWith(loyaltyPoints: newPoints.clamp(0, int.infinity));
  }

  // Get customer ranking
  String get customerRanking {
    if (totalPurchases > 50000) return 'Platinum';
    if (totalPurchases > 20000) return 'Gold';
    if (totalPurchases > 10000) return 'Silver';
    if (totalPurchases > 5000) return 'Bronze';
    return 'Regular';
  }

  // Get customer activity level
  String get activityLevel {
    if (totalPurchases > 20000) return 'High';
    if (totalPurchases > 10000) return 'Medium';
    if (totalPurchases > 5000) return 'Low';
    return 'New';
  }

  // Get customer communication preferences
  Map<String, bool> get communicationPreferences {
    return {
      'email': email != null && email!.isNotEmpty,
      'sms': true, // Always allow SMS
      'whatsapp': phoneNumber.contains('+91'),
      'push': true,
    };
  }

  // Get customer tags
  List<String> get customerTags {
    final tags = <String>[];

    if (isWholesaleCustomer) tags.add('Wholesale');
    if (membershipTier != 'None') tags.add(membershipTier);
    if (walletBalance > 1000) tags.add('Premium');
    if (loyaltyPoints >= 1000) tags.add('VIP');

    return tags;
  }
}