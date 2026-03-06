import 'package:isar/isar.dart';

part 'batch_schema.g.dart';

@collection
class BatchSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int batchId; // Remote Django ID

  late int itemId;
  late String batchNumber;
  late String manufacturer;
  late DateTime manufactureDate;
  late DateTime expiryDate;
  late int quantity;
  late double purchasePrice;
  late double sellingPrice;
  late double wholesalePrice;
  late String storageCondition;
  late bool isExpired;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Conversion methods
  BatchSchema.fromDomain(Batch batch) {
    batchId = batch.id;
    itemId = batch.itemId;
    batchNumber = batch.batchNumber;
    manufacturer = batch.manufacturer;
    manufactureDate = batch.manufactureDate;
    expiryDate = batch.expiryDate;
    quantity = batch.quantity;
    purchasePrice = batch.purchasePrice;
    sellingPrice = batch.sellingPrice;
    wholesalePrice = batch.wholesalePrice;
    storageCondition = batch.storageCondition;
    isExpired = batch.isExpired;
    createdAt = batch.createdAt;
    updatedAt = batch.updatedAt;
  }

  Batch toDomain() {
    return Batch(
      id: batchId,
      itemId: itemId,
      batchNumber: batchNumber,
      manufacturer: manufacturer,
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
      quantity: quantity,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      wholesalePrice: wholesalePrice,
      storageCondition: storageCondition,
      isExpired: isExpired,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

@collection
class StockMovementSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int movementId; // Remote Django ID

  late int itemId;
  late int batchId;
  late int quantity;
  late double unitCost;
  late String movementType; // 'inward', 'outward', 'adjustment', 'return'
  late String referenceType; // 'purchase', 'sale', 'transfer', 'damage'
  late String referenceId;
  late String notes;
  late int userId;
  late DateTime movementDate;
  late DateTime createdAt;
  late DateTime updatedAt;

  // Additional fields
  String? supplierName;
  String? customerName;

  // Conversion methods
  StockMovementSchema.fromDomain(StockMovement movement) {
    movementId = movement.id;
    itemId = movement.itemId;
    batchId = movement.batchId;
    quantity = movement.quantity;
    unitCost = movement.unitCost;
    movementType = movement.movementType;
    referenceType = movement.referenceType;
    referenceId = movement.referenceId;
    notes = movement.notes;
    userId = movement.userId;
    movementDate = movement.movementDate;
    createdAt = movement.createdAt;
    updatedAt = movement.updatedAt;
    supplierName = movement.supplierName;
    customerName = movement.customerName;
  }

  StockMovement toDomain() {
    return StockMovement(
      id: movementId,
      itemId: itemId,
      batchId: batchId,
      quantity: quantity,
      unitCost: unitCost,
      movementType: movementType,
      referenceType: referenceType,
      referenceId: referenceId,
      notes: notes,
      userId: userId,
      movementDate: movementDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      supplierName: supplierName,
      customerName: customerName,
    );
  }
}

@collection
class LowStockAlertSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int alertId; // Remote Django ID

  late int itemId;
  late int currentStock;
  late int threshold;
  late bool isResolved;
  late DateTime alertDate;
  late DateTime resolvedDate;
  late String resolutionNotes;
  late int userId;

  // Conversion methods
  LowStockAlertSchema.fromDomain(LowStockAlert alert) {
    alertId = alert.id;
    itemId = alert.itemId;
    currentStock = alert.currentStock;
    threshold = alert.threshold;
    isResolved = alert.isResolved;
    alertDate = alert.alertDate;
    resolvedDate = alert.resolvedDate;
    resolutionNotes = alert.resolutionNotes;
    userId = alert.userId;
  }

  LowStockAlert toDomain() {
    return LowStockAlert(
      id: alertId,
      itemId: itemId,
      currentStock: currentStock,
      threshold: threshold,
      isResolved: isResolved,
      alertDate: alertDate,
      resolvedDate: resolvedDate,
      resolutionNotes: resolutionNotes,
      userId: userId,
    );
  }
}