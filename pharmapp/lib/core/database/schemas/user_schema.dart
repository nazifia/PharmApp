import 'package:isar/isar.dart';

part 'user_schema.g.dart';

@collection
class UserSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int userId; // Remote Django ID

  late String phoneNumber;
  late String role; // e.g., 'Admin', 'Pharmacist', 'Cashier'
  late bool isActive;
  late bool isWholesaleOperator;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Profile information
  String? firstName;
  String? lastName;
  String? email;
  String? profileImageUrl;

  // Permissions
  List<String> permissions = [];

  // Conversion methods
  UserSchema.fromDomain(User user) {
    userId = user.id;
    phoneNumber = user.phoneNumber;
    role = user.role;
    isActive = user.isActive;
    isWholesaleOperator = user.isWholesaleOperator;
  }

  User toDomain() {
    return User(
      id: userId,
      phoneNumber: phoneNumber,
      role: role,
      isActive: isActive,
      isWholesaleOperator: isWholesaleOperator,
    );
  }
}

@collection
class CustomerSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int customerId; // Remote Django ID

  late String name;
  late String phoneNumber;
  String? email;
  String? address;
  late double walletBalance;
  late bool isWholesaleCustomer;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Loyalty information
  int loyaltyPoints = 0;
  int totalPurchases = 0;

  // Conversion methods
  CustomerSchema.fromDomain(Customer customer) {
    customerId = customer.id;
    name = customer.name;
    phoneNumber = customer.phoneNumber;
    email = customer.email;
    address = customer.address;
    walletBalance = customer.walletBalance;
    isWholesaleCustomer = customer.isWholesaleCustomer;
    loyaltyPoints = customer.loyaltyPoints;
    totalPurchases = customer.totalPurchases;
  }

  Customer toDomain() {
    return Customer(
      id: customerId,
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      address: address,
      walletBalance: walletBalance,
      isWholesaleCustomer: isWholesaleCustomer,
      loyaltyPoints: loyaltyPoints,
      totalPurchases: totalPurchases,
    );
  }
}

@collection
class SupplierSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int supplierId; // Remote Django ID

  late String name;
  late String contactPerson;
  late String phoneNumber;
  late String email;
  late String address;
  late String gstNumber;
  late bool isActive;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Conversion methods
  SupplierSchema.fromDomain(Supplier supplier) {
    supplierId = supplier.id;
    name = supplier.name;
    contactPerson = supplier.contactPerson;
    phoneNumber = supplier.phoneNumber;
    email = supplier.email;
    address = supplier.address;
    gstNumber = supplier.gstNumber;
    isActive = supplier.isActive;
  }

  Supplier toDomain() {
    return Supplier(
      id: supplierId,
      name: name,
      contactPerson: contactPerson,
      phoneNumber: phoneNumber,
      email: email,
      address: address,
      gstNumber: gstNumber,
      isActive: isActive,
    );
  }
}