class PurchaseOrderItem {
  final int? id;
  final int itemId;
  final String itemName;
  final int quantityOrdered;
  final int quantityReceived;
  final double unitCost;

  const PurchaseOrderItem({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderItem(
        id: json['id'] as int?,
        itemId: (json['item_id'] ?? json['itemId'] ?? 0) as int,
        itemName: (json['item_name'] ?? json['itemName'] ?? '') as String,
        quantityOrdered:
            (json['quantity_ordered'] ?? json['quantityOrdered'] ?? 0) as int,
        quantityReceived:
            (json['quantity_received'] ?? json['quantityReceived'] ?? 0) as int,
        unitCost: ((json['unit_cost'] ?? json['unitCost'] ?? 0) as num)
            .toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'item_id': itemId,
        'item_name': itemName,
        'quantity_ordered': quantityOrdered,
        'quantity_received': quantityReceived,
        'unit_cost': unitCost,
      };
}

class PurchaseOrder {
  final int? id;
  final int supplierId;
  final String supplierName;
  final String status;
  final DateTime? createdAt;
  final DateTime? expectedDelivery;
  final List<PurchaseOrderItem> items;
  final String? notes;

  const PurchaseOrder({
    this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    this.createdAt,
    this.expectedDelivery,
    required this.items,
    this.notes,
  });

  double get total =>
      items.fold(0.0, (sum, i) => sum + i.unitCost * i.quantityOrdered);

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
        id: json['id'] as int?,
        supplierId:
            (json['supplier_id'] ?? json['supplierId'] ?? 0) as int,
        supplierName:
            (json['supplier_name'] ?? json['supplierName'] ?? '') as String,
        status: (json['status'] ?? 'draft') as String,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'] as String)
                : null,
        expectedDelivery: json['expected_delivery'] != null
            ? DateTime.tryParse(json['expected_delivery'] as String)
            : json['expectedDelivery'] != null
                ? DateTime.tryParse(json['expectedDelivery'] as String)
                : null,
        items: ((json['items'] as List?) ?? [])
            .map((e) =>
                PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (expectedDelivery != null)
          'expected_delivery':
              expectedDelivery!.toIso8601String().split('T').first,
        'items': items.map((i) => i.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}
