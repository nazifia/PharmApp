/// Branch model — plain Dart, no codegen needed.
library;

class Branch {
  final int    id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final bool   isActive;
  final bool   isMain;
  final DateTime? createdAt;

  const Branch({
    required this.id,
    required this.name,
    this.address  = '',
    this.phone    = '',
    this.email    = '',
    this.isActive = true,
    this.isMain   = false,
    this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id:        (json['id'] as num).toInt(),
        name:      json['name']    as String? ?? '',
        address:   json['address'] as String? ?? '',
        phone:     json['phone']   as String? ?? '',
        email:     json['email']   as String? ?? '',
        isActive:  json['isActive'] as bool?  ?? true,
        isMain:    json['isMain']   as bool?  ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id':        id,
        'name':      name,
        'address':   address,
        'phone':     phone,
        'email':     email,
        'isActive':  isActive,
        'isMain':    isMain,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  Branch copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    bool?   isActive,
    bool?   isMain,
  }) =>
      Branch(
        id:        id,
        name:      name      ?? this.name,
        address:   address   ?? this.address,
        phone:     phone     ?? this.phone,
        email:     email     ?? this.email,
        isActive:  isActive  ?? this.isActive,
        isMain:    isMain    ?? this.isMain,
        createdAt: createdAt,
      );
}
