class Customer {
  final int id;
  final String name;
  final String phone;
  final bool isWholesale;
  final double walletBalance;
  final int totalPurchases;
  final double outstandingDebt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.isWholesale,
    required this.walletBalance,
    required this.totalPurchases,
    required this.outstandingDebt,
  });

  String get type => isWholesale ? 'Wholesale' : 'Retail';

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id:              json['id'] as int,
        name:            (json['name']            as String?) ?? '',
        phone:           (json['phone']           as String?) ?? '',
        isWholesale:     (json['is_wholesale']    as bool?)   ?? false,
        walletBalance:   (json['wallet_balance']  as num?)?.toDouble()  ?? 0.0,
        totalPurchases:  (json['total_purchases'] as num?)?.toInt()     ?? 0,
        outstandingDebt: (json['outstanding_debt'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'name':         name,
        'phone':        phone,
        'is_wholesale': isWholesale,
      };
}
