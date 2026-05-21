class Hospital {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String? city;

  const Hospital({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.city,
  });

  String get displayName => city != null ? '$name, $city' : name;

  factory Hospital.fromJson(Map<String, dynamic> j) => Hospital(
        id:      (j['id'] as num?)?.toInt() ?? 0,
        name:    (j['name'] as String?) ?? '',
        address: j['address'] as String?,
        phone:   j['phone'] as String?,
        city:    j['city'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (city != null && city!.isNotEmpty) 'city': city,
      };

  Hospital copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    String? city,
  }) =>
      Hospital(
        id:      id ?? this.id,
        name:    name ?? this.name,
        address: address ?? this.address,
        phone:   phone ?? this.phone,
        city:    city ?? this.city,
      );
}
