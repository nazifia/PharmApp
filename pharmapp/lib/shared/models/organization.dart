class Organization {
  final int id;
  final String name;
  final String slug;
  final String? address;
  final String? phone;
  final String? logoUrl;

  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.phone,
    this.logoUrl,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        logoUrl: json['logoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (logoUrl != null) 'logoUrl': logoUrl,
      };
}
