class Customer {
  final int id;
  final String name;
  final String phone;
  final bool isWholesale;
  final double walletBalance;
  final int totalPurchases;
  final double outstandingDebt;

  // Optional detail fields (returned by /customers/{id}/ endpoint)
  final String? email;
  final String? address;
  final double? totalSpent;
  final String? joinDate;
  final String? lastVisit;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.isWholesale,
    required this.walletBalance,
    required this.totalPurchases,
    required this.outstandingDebt,
    this.email,
    this.address,
    this.totalSpent,
    this.joinDate,
    this.lastVisit,
  });

  String get type => isWholesale ? 'Wholesale' : 'Retail';

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id:              json['id'] as int,
        name:            (json['name']             as String?) ?? '',
        phone:           (json['phone']            as String?) ?? '',
        isWholesale:     (json['is_wholesale']     as bool?)   ?? false,
        walletBalance:   (json['wallet_balance']   as num?)?.toDouble()  ?? 0.0,
        totalPurchases:  (json['total_purchases']  as num?)?.toInt()     ?? 0,
        outstandingDebt: (json['outstanding_debt'] as num?)?.toDouble()  ?? 0.0,
        email:           json['email']      as String?,
        address:         json['address']    as String?,
        totalSpent:      (json['total_spent'] as num?)?.toDouble(),
        joinDate:        json['join_date']  as String?,
        lastVisit:       json['last_visit'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name':         name,
        'phone':        phone,
        'is_wholesale': isWholesale,
      };
}
