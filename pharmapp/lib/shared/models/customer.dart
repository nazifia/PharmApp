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

  // Network patient flag — visible across all pharmacies in the network
  final bool isNetworkPatient;

  // Medical history fields
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final String? bloodGroup;
  final DateTime? dateOfBirth;

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
    this.isNetworkPatient = false,
    this.allergies = const <String>[],
    this.chronicConditions = const <String>[],
    this.currentMedications = const <String>[],
    this.bloodGroup,
    this.dateOfBirth,
  });

  String get type => isWholesale ? 'Wholesale' : 'Retail';
  String get patientType => isNetworkPatient ? 'Network Patient' : type;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id:              json['id'] as int,
        name:            (json['name']             as String?) ?? '',
        phone:           (json['phone']            as String?) ?? '',
        isWholesale:     (json['is_wholesale']     as bool?)   ?? false,
        isNetworkPatient: (json['is_network_patient'] as bool?) ?? false,
        walletBalance:   (json['wallet_balance']   as num?)?.toDouble()  ?? 0.0,
        totalPurchases:  (json['total_purchases']  as num?)?.toInt()     ?? 0,
        outstandingDebt: (json['outstanding_debt'] as num?)?.toDouble()  ?? 0.0,
        email:           json['email']      as String?,
        address:         json['address']    as String?,
        totalSpent:      (json['total_spent'] as num?)?.toDouble(),
        joinDate:        json['join_date']  as String?,
        lastVisit:       json['last_visit'] as String?,
        allergies:       (json['allergies'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        chronicConditions: (json['chronic_conditions'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        currentMedications: (json['current_medications'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        bloodGroup:      json['blood_group'] as String?,
        dateOfBirth:     json['date_of_birth'] != null
            ? DateTime.tryParse(json['date_of_birth'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name':         name,
        'phone':        phone,
        'is_wholesale': isWholesale,
        'is_network_patient': isNetworkPatient,
        if (email != null)   'email':   email,
        if (address != null) 'address': address,
        if (allergies.isNotEmpty)          'allergies':            allergies,
        if (chronicConditions.isNotEmpty)  'chronic_conditions':   chronicConditions,
        if (currentMedications.isNotEmpty) 'current_medications':  currentMedications,
        if (bloodGroup != null)            'blood_group':          bloodGroup,
        if (dateOfBirth != null)           'date_of_birth':
            '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth!.day.toString().padLeft(2, '0')}',
      };

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    bool? isWholesale,
    double? walletBalance,
    int? totalPurchases,
    double? outstandingDebt,
    String? email,
    String? address,
    double? totalSpent,
    String? joinDate,
    String? lastVisit,
    bool? isNetworkPatient,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? currentMedications,
    String? bloodGroup,
    DateTime? dateOfBirth,
    bool clearBloodGroup = false,
    bool clearDateOfBirth = false,
  }) =>
      Customer(
        id:               id              ?? this.id,
        name:             name            ?? this.name,
        phone:            phone           ?? this.phone,
        isWholesale:      isWholesale     ?? this.isWholesale,
        walletBalance:    walletBalance   ?? this.walletBalance,
        totalPurchases:   totalPurchases  ?? this.totalPurchases,
        outstandingDebt:  outstandingDebt ?? this.outstandingDebt,
        email:            email           ?? this.email,
        address:          address         ?? this.address,
        totalSpent:       totalSpent      ?? this.totalSpent,
        joinDate:         joinDate        ?? this.joinDate,
        lastVisit:        lastVisit       ?? this.lastVisit,
        isNetworkPatient: isNetworkPatient ?? this.isNetworkPatient,
        allergies:        allergies       ?? this.allergies,
        chronicConditions: chronicConditions ?? this.chronicConditions,
        currentMedications: currentMedications ?? this.currentMedications,
        bloodGroup:       clearBloodGroup  ? null : (bloodGroup  ?? this.bloodGroup),
        dateOfBirth:      clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      );
}
