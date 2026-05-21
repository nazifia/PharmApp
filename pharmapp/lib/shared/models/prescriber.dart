class Prescriber {
  final int id;
  final String name;
  final String? licenseNumber;
  final String? specialty;
  final String? phone;
  final String? clinic;
  final String? address;
  final bool isVerified;
  final bool isNetworkShared;
  final String? createdAt;

  const Prescriber({
    required this.id,
    required this.name,
    this.licenseNumber,
    this.specialty,
    this.phone,
    this.clinic,
    this.address,
    this.isVerified = false,
    this.isNetworkShared = false,
    this.createdAt,
  });

  String get displayName =>
      licenseNumber != null ? '$name ($licenseNumber)' : name;

  String get specialtyLabel => specialty ?? 'General Practitioner';

  factory Prescriber.fromJson(Map<String, dynamic> j) => Prescriber(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        licenseNumber: (j['license_number'] ?? j['licenseNumber']) as String?,
        specialty: j['specialty'] as String?,
        phone: j['phone'] as String?,
        clinic: (j['clinic'] ?? j['clinic_name']) as String?,
        address: j['address'] as String?,
        isVerified: (j['is_verified'] ?? j['isVerified'] as bool?) ?? false,
        isNetworkShared:
            (j['is_network_shared'] ?? j['isNetworkShared'] as bool?) ?? false,
        createdAt: (j['created_at'] ?? j['createdAt']) as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (licenseNumber != null && licenseNumber!.isNotEmpty)
          'license_number': licenseNumber,
        if (specialty != null && specialty!.isNotEmpty) 'specialty': specialty,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (clinic != null && clinic!.isNotEmpty) 'clinic': clinic,
        if (address != null && address!.isNotEmpty) 'address': address,
        'is_network_shared': isNetworkShared,
      };

  Prescriber copyWith({
    int? id,
    String? name,
    String? licenseNumber,
    String? specialty,
    String? phone,
    String? clinic,
    String? address,
    bool? isVerified,
    bool? isNetworkShared,
    String? createdAt,
  }) =>
      Prescriber(
        id: id ?? this.id,
        name: name ?? this.name,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        specialty: specialty ?? this.specialty,
        phone: phone ?? this.phone,
        clinic: clinic ?? this.clinic,
        address: address ?? this.address,
        isVerified: isVerified ?? this.isVerified,
        isNetworkShared: isNetworkShared ?? this.isNetworkShared,
        createdAt: createdAt ?? this.createdAt,
      );
}
