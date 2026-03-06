import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'supplier_model.freezed.dart';
part 'supplier_model.g.dart';

@freezed
class Supplier with _$Supplier {
  const factory Supplier({
    required int id,
    required String name,
    required String contactPerson,
    required String phoneNumber,
    required String email,
    required String address,
    required String gstNumber,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    required double rating,
    required String? website,
    required String? panNumber,
    required String? bankAccount,
    required String? ifscCode,
    required List<String> products,
    required Map<String, dynamic> performance,
  }) = _Supplier;

  factory Supplier.fromJson(Map<String, dynamic> json) => _$SupplierFromJson(json);

  // Validation
  bool get isValid =>
    name.isNotEmpty &&
    contactPerson.isNotEmpty &&
    phoneNumber.isNotEmpty &&
    phoneNumber.length >= 10 &&
    email.isNotEmpty &&
    email.contains('@') &&
    address.isNotEmpty &&
    gstNumber.isNotEmpty &&
    gstNumber.length >= 15 &&
    rating >= 0 && rating <= 5;

  // Get formatted information
  String get formattedCreatedAt => DateFormat('dd MMM yyyy').format(createdAt);

  String get formattedUpdatedAt => DateFormat('dd MMM yyyy').format(updatedAt);

  String get formattedPhoneNumber => phoneNumber;

  String get formattedEmail => email;

  String get formattedRating => '${rating.toStringAsFixed(1)}/5.0';

  // Get supplier type
  String get supplierType {
    if (gstNumber.startsWith('29')) return 'Local Supplier';
    if (gstNumber.startsWith('07')) return 'National Supplier';
    if (gstNumber.startsWith('91')) return 'International Supplier';
    return 'General Supplier';
  }

  // Get supplier status
  String get supplierStatus {
    return isActive ? 'Active' : 'Inactive';
  }

  // Get supplier performance
  String get performanceSummary {
    final deliveryTime = performance['deliveryTime'] ?? '3-5 days';
    final quality = performance['quality'] ?? 4.0;
    final price = performance['price'] ?? 4.0;
    final communication = performance['communication'] ?? 4.0;

    return 'Delivery: $deliveryTime | Quality: $quality | Price: $price | Communication: $communication';
  }

  // Get supplier metadata
  Map<String, dynamic> get metadata {
    return {
      'id': id,
      'name': name,
      'contact': contactPerson,
      'phone': phoneNumber,
      'email': email,
      'address': address,
      'gst': gstNumber,
      'status': supplierStatus,
      'rating': rating,
      'website': website,
      'pan': panNumber,
      'bankAccount': bankAccount,
      'ifsc': ifscCode,
      'products': products,
      'performance': performance,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Get supplier summary
  String get supplierSummary {
    return '$name - $contactPerson | $supplierStatus | $formattedRating';
  }

  // Get supplier address
  String get fullAddress {
    return address;
  }

  // Get supplier contact information
  String get contactInfo {
    return 'Contact: $contactPerson\nPhone: $phoneNumber\nEmail: $email';
  }

  // Get supplier GST information
  String get gstInfo {
    return 'GSTIN: $gstNumber | Type: $supplierType';
  }

  // Get supplier bank information
  String get bankInfo {
    if (bankAccount != null && ifscCode != null) {
      return 'Account: $bankAccount | IFSC: $ifscCode';
    } else if (bankAccount != null) {
      return 'Account: $bankAccount';
    } else {
      return 'Bank Details Not Provided';
    }
  }

  // Get supplier website
  String get websiteUrl {
    if (website != null && website!.startsWith('http')) {
      return website!;
    } else if (website != null) {
      return 'https://$website';
    } else {
      return 'https://www.$name.com';
    }
  }

  // Get supplier products
  String get productList {
    if (products.isEmpty) return 'Various Products';
    return products.take(3).join(', ') + (products.length > 3 ? '...' : '');
  }

  // Get supplier tags
  List<String> get supplierTags {
    final tags = <String>[];

    if (isActive) tags.add('Active');
    if (rating >= 4.5) tags.add('Top Rated');
    if (supplierType == 'Local Supplier') tags.add('Local');
    if (products.contains('Pharmaceuticals')) tags.add('Pharmaceuticals');

    return tags;
  }

  // Get supplier performance metrics
  Map<String, dynamic> get performanceMetrics {
    return {
      'deliveryTime': performance['deliveryTime'] ?? '3-5 days',
      'qualityRating': performance['quality'] ?? 4.0,
      'priceRating': performance['price'] ?? 4.0,
      'communicationRating': performance['communication'] ?? 4.0,
      'onTimeDelivery': performance['onTimeDelivery'] ?? 95.0,
      'orderAccuracy': performance['orderAccuracy'] ?? 98.0,
    };
  }

  // Get supplier documents
  List<String> get requiredDocuments {
    return [
      'GST Registration Certificate',
      'PAN Card',
      'Bank Account Details',
      'Company Registration',
      'Import Export Code (if applicable)',
      'Product Catalog',
      'Price List',
    ];
  }

  // Get supplier categories
  List<String> get supplierCategories {
    return [
      'Pharmaceuticals',
      'Medical Supplies',
      'Healthcare Products',
      'Wellness Products',
      'Nutraceuticals',
    ];

    // Get supplier availability
  bool get isAvailable {
    return isActive && DateTime.now().difference(updatedAt).inDays < 30;
  }

  // Get supplier priority
  String get priority {
    if (rating >= 4.5) return 'High';
    if (rating >= 4.0) return 'Medium';
    return 'Low';
  }

  // Get supplier communication channels
  Map<String, String> get communicationChannels {
    return {
      'phone': phoneNumber,
      'email': email,
      'whatsapp': phoneNumber.contains('+91') ? phoneNumber : '',
      'website': website ?? '',
    };
  }

  // Copy with updated values
  Supplier copyWith({
    int? id,
    String? name,
    String? contactPerson,
    String? phoneNumber,
    String? email,
    String? address,
    String? gstNumber,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    String? website,
    String? panNumber,
    String? bankAccount,
    String? ifscCode,
    List<String>? products,
    Map<String, dynamic>? performance,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      website: website ?? this.website,
      panNumber: panNumber ?? this.panNumber,
      bankAccount: bankAccount ?? this.bankAccount,
      ifscCode: ifscCode ?? this.ifscCode,
      products: products ?? this.products,
      performance: performance ?? this.performance,
    );
  }
}