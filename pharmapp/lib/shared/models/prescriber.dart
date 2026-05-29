class Prescriber {
  final int id;
  final String name;
  final String? licenseNumber;
  final String? specialty;
  final String? phone;
  final int? hospitalId;
  final String? hospitalName;
  final String? address;
  final bool isVerified;
  final String? createdAt;
  final double commissionRate; // percentage, e.g. 5.0 = 5%

  const Prescriber({
    required this.id,
    required this.name,
    this.licenseNumber,
    this.specialty,
    this.phone,
    this.hospitalId,
    this.hospitalName,
    this.address,
    this.isVerified = false,
    this.createdAt,
    this.commissionRate = 0.0,
  });

  String get displayName =>
      licenseNumber != null ? '$name ($licenseNumber)' : name;

  String get specialtyLabel => specialty ?? 'General Practitioner';

  factory Prescriber.fromJson(Map<String, dynamic> j) => Prescriber(
        id:             (j['id'] as num?)?.toInt() ?? 0,
        name:           (j['name'] as String?) ?? '',
        licenseNumber:  (j['license_number'] ?? j['licenseNumber']) as String?,
        specialty:      j['specialty'] as String?,
        phone:          j['phone'] as String?,
        hospitalId:     (j['hospital_id'] as num?)?.toInt(),
        hospitalName:   (j['hospital_name'] ??
                         j['hospitalName'] ??
                         j['clinic'] ??
                         j['clinic_name']) as String?,
        address:        j['address'] as String?,
        isVerified:     (j['is_verified'] ?? j['isVerified'] as bool?) ?? false,
        createdAt:      (j['created_at'] ?? j['createdAt']) as String?,
        commissionRate: ((j['commission_rate'] ?? j['commissionRate']) as num?)
                            ?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (licenseNumber != null && licenseNumber!.isNotEmpty)
          'license_number': licenseNumber,
        if (specialty != null && specialty!.isNotEmpty) 'specialty': specialty,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (hospitalId != null) 'hospital_id': hospitalId,
        if (address != null && address!.isNotEmpty) 'address': address,
        'commission_rate': commissionRate,
      };

  Prescriber copyWith({
    int? id,
    String? name,
    String? licenseNumber,
    String? specialty,
    String? phone,
    int? hospitalId,
    String? hospitalName,
    String? address,
    bool? isVerified,
    String? createdAt,
    double? commissionRate,
  }) =>
      Prescriber(
        id:             id ?? this.id,
        name:           name ?? this.name,
        licenseNumber:  licenseNumber ?? this.licenseNumber,
        specialty:      specialty ?? this.specialty,
        phone:          phone ?? this.phone,
        hospitalId:     hospitalId ?? this.hospitalId,
        hospitalName:   hospitalName ?? this.hospitalName,
        address:        address ?? this.address,
        isVerified:     isVerified ?? this.isVerified,
        createdAt:      createdAt ?? this.createdAt,
        commissionRate: commissionRate ?? this.commissionRate,
      );
}
