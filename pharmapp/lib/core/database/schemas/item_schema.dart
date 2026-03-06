import 'package:isar/isar.dart';

part 'item_schema.g.dart';

@collection
class ItemSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int itemId; // Remote Django ID

  late String name;
  late String brand;
  late String dosageForm;
  late String genericName;
  late String manufacturer;
  late String category;
  late String subCategory;
  late double purchasePrice;
  late double sellingPrice;
  late double wholesalePrice;
  late int stock;
  late int lowStockThreshold;
  late int reorderLevel;
  late bool isPrescriptionRequired;
  late DateTime? expiryDate;
  late DateTime? manufactureDate;
  late String barcode;
  late String batchNumber;
  late String storageCondition;
  late bool isDiscountable;
  late double discountPercentage;
  late String unit;
  late String packageSize;
  late String packageUnit;
  late bool isTaxable;
  late double taxRate;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Additional fields for advanced features
  List<String> tags = [];
  List<String> alternativeBrands = [];
  String? imageUrl;
  String? description;
  bool isFeatured = false;
  bool isPopular = false;

  // Conversion methods
  ItemSchema.fromDomain(Item item) {
    itemId = item.id;
    name = item.name;
    brand = item.brand;
    dosageForm = item.dosageForm;
    genericName = item.genericName;
    manufacturer = item.manufacturer;
    category = item.category;
    subCategory = item.subCategory;
    purchasePrice = item.purchasePrice;
    sellingPrice = item.sellingPrice;
    wholesalePrice = item.wholesalePrice;
    stock = item.stock;
    lowStockThreshold = item.lowStockThreshold;
    reorderLevel = item.reorderLevel;
    isPrescriptionRequired = item.isPrescriptionRequired;
    expiryDate = item.expiryDate;
    manufactureDate = item.manufactureDate;
    barcode = item.barcode;
    batchNumber = item.batchNumber;
    storageCondition = item.storageCondition;
    isDiscountable = item.isDiscountable;
    discountPercentage = item.discountPercentage;
    unit = item.unit;
    packageSize = item.packageSize;
    packageUnit = item.packageUnit;
    isTaxable = item.isTaxable;
    taxRate = item.taxRate;
    createdAt = item.createdAt;
    updatedAt = item.updatedAt;
    tags = item.tags;
    alternativeBrands = item.alternativeBrands;
    imageUrl = item.imageUrl;
    description = item.description;
    isFeatured = item.isFeatured;
    isPopular = item.isPopular;
  }

  Item toDomain() {
    return Item(
      id: itemId,
      name: name,
      brand: brand,
      dosageForm: dosageForm,
      genericName: genericName,
      manufacturer: manufacturer,
      category: category,
      subCategory: subCategory,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      wholesalePrice: wholesalePrice,
      stock: stock,
      lowStockThreshold: lowStockThreshold,
      reorderLevel: reorderLevel,
      isPrescriptionRequired: isPrescriptionRequired,
      expiryDate: expiryDate,
      manufactureDate: manufactureDate,
      barcode: barcode,
      batchNumber: batchNumber,
      storageCondition: storageCondition,
      isDiscountable: isDiscountable,
      discountPercentage: discountPercentage,
      unit: unit,
      packageSize: packageSize,
      packageUnit: packageUnit,
      isTaxable: isTaxable,
      taxRate: taxRate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags,
      alternativeBrands: alternativeBrands,
      imageUrl: imageUrl,
      description: description,
      isFeatured: isFeatured,
      isPopular: isPopular,
    );
  }
}

@collection
class CartSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int cartId; // Remote Django ID

  @Index(type: IndexType.value)
  late int userId;
  late int itemId;
  late int quantity;
  late double unitPrice;
  late double subtotal;
  late double discount;
  late double total;
  late String status; // 'active', 'checked_out', 'cancelled'
  late DateTime createdAt;
  late DateTime updatedAt;

  // Additional fields for retail/wholesale
  bool isWholesale = false;
  String? customerPhone;
  String? customerName;

  // Conversion methods
  CartSchema.fromDomain(CartItem cartItem) {
    cartId = cartItem.id;
    userId = cartItem.userId;
    itemId = cartItem.itemId;
    quantity = cartItem.quantity;
    unitPrice = cartItem.unitPrice;
    subtotal = cartItem.subtotal;
    discount = cartItem.discount;
    total = cartItem.total;
    status = cartItem.status;
    createdAt = cartItem.createdAt;
    updatedAt = cartItem.updatedAt;
    isWholesale = cartItem.isWholesale;
    customerPhone = cartItem.customerPhone;
    customerName = cartItem.customerName;
  }

  CartItem toDomain() {
    return CartItem(
      id: cartId,
      userId: userId,
      itemId: itemId,
      quantity: quantity,
      unitPrice: unitPrice,
      subtotal: subtotal,
      discount: discount,
      total: total,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isWholesale: isWholesale,
      customerPhone: customerPhone,
      customerName: customerName,
    );
  }
}

@collection
class SaleSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int saleId; // Remote Django ID

  @Index(type: IndexType.value)
  late int userId;
  late int customerId;
  late double totalAmount;
  late double discountAmount;
  late double taxAmount;
  late double finalAmount;
  late String paymentMethod; // 'cash', 'card', 'wallet', 'split'
  late String paymentStatus; // 'paid', 'pending', 'refunded'
  late bool isWholesale;
  late bool isReturn;
  late String returnReason;
  late DateTime saleDate;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Payment details for split payments
  double cashPayment = 0.0;
  double cardPayment = 0.0;
  double walletPayment = 0.0;
  double bankTransferPayment = 0.0;

  // Additional fields
  String? invoiceNumber;
  String? customerName;
  String? customerPhone;
  List<int> itemIds = [];
  List<int> quantities = [];
  List<double> prices = [];

  // Conversion methods
  SaleSchema.fromDomain(Sale sale) {
    saleId = sale.id;
    userId = sale.userId;
    customerId = sale.customerId;
    totalAmount = sale.totalAmount;
    discountAmount = sale.discountAmount;
    taxAmount = sale.taxAmount;
    finalAmount = sale.finalAmount;
    paymentMethod = sale.paymentMethod;
    paymentStatus = sale.paymentStatus;
    isWholesale = sale.isWholesale;
    isReturn = sale.isReturn;
    returnReason = sale.returnReason;
    saleDate = sale.saleDate;
    createdAt = sale.createdAt;
    updatedAt = sale.updatedAt;
    cashPayment = sale.cashPayment;
    cardPayment = sale.cardPayment;
    walletPayment = sale.walletPayment;
    bankTransferPayment = sale.bankTransferPayment;
    invoiceNumber = sale.invoiceNumber;
    customerName = sale.customerName;
    customerPhone = sale.customerPhone;
    itemIds = sale.itemIds;
    quantities = sale.quantities;
    prices = sale.prices;
  }

  Sale toDomain() {
    return Sale(
      id: saleId,
      userId: userId,
      customerId: customerId,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      finalAmount: finalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      isWholesale: isWholesale,
      isReturn: isReturn,
      returnReason: returnReason,
      saleDate: saleDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      cashPayment: cashPayment,
      cardPayment: cardPayment,
      walletPayment: walletPayment,
      bankTransferPayment: bankTransferPayment,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      itemIds: itemIds,
      quantities: quantities,
      prices: prices,
    );
  }
}