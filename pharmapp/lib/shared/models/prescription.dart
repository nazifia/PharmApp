class PrescriptionItem {
  final int? itemId;
  final String itemName;
  final String? brand;
  final double quantity;
  final String unit;
  final String? dosage;
  final String? duration;
  final String? instructions;
  final bool isDispensed;
  final String? dispensedAt;

  const PrescriptionItem({
    this.itemId,
    required this.itemName,
    this.brand,
    required this.quantity,
    this.unit = 'unit(s)',
    this.dosage,
    this.duration,
    this.instructions,
    this.isDispensed = false,
    this.dispensedAt,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> j) => PrescriptionItem(
        itemId: (j['item_id'] ?? j['itemId']) as int?,
        itemName: (j['item_name'] ?? j['itemName'] ?? j['name'] as String?) ?? '',
        brand: j['brand'] as String?,
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        unit: (j['unit'] as String?) ?? 'unit(s)',
        dosage: j['dosage'] as String?,
        duration: j['duration'] as String?,
        instructions: j['instructions'] as String?,
        isDispensed: (j['is_dispensed'] ?? j['isDispensed'] as bool?) ?? false,
        dispensedAt: j['dispensed_at'] ?? j['dispensedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (itemId != null) 'item_id': itemId,
        'item_name': itemName,
        if (brand != null) 'brand': brand,
        'quantity': quantity,
        'unit': unit,
        if (dosage != null) 'dosage': dosage,
        if (duration != null) 'duration': duration,
        if (instructions != null) 'instructions': instructions,
      };

  PrescriptionItem copyWith({bool? isDispensed, String? dispensedAt}) =>
      PrescriptionItem(
        itemId: itemId,
        itemName: itemName,
        brand: brand,
        quantity: quantity,
        unit: unit,
        dosage: dosage,
        duration: duration,
        instructions: instructions,
        isDispensed: isDispensed ?? this.isDispensed,
        dispensedAt: dispensedAt ?? this.dispensedAt,
      );
}

class Prescription {
  final int id;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final String? doctorName;
  final String? diagnosis;
  final String? notes;
  final List<PrescriptionItem> medications;
  final String status; // 'pending' | 'partial' | 'dispensed'
  final String createdAt;
  final String? dispensedAt;
  final String? createdByName;
  final int? createdById;
  final String? pharmacyName;
  final int? pharmacyId;

  const Prescription({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.doctorName,
    this.diagnosis,
    this.notes,
    required this.medications,
    required this.status,
    required this.createdAt,
    this.dispensedAt,
    this.createdByName,
    this.createdById,
    this.pharmacyName,
    this.pharmacyId,
  });

  bool get isPending => status == 'pending';
  bool get isPartial => status == 'partial';
  bool get isDispensed => status == 'dispensed';

  int get undispensedCount => medications.where((m) => !m.isDispensed).length;
  int get dispensedCount => medications.where((m) => m.isDispensed).length;

  factory Prescription.fromJson(Map<String, dynamic> j) {
    final rawDate = (j['created_at'] ?? j['createdAt'] as String?) ?? '';
    String formatted = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        formatted = '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
            '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:'
            '${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
      } catch (_) {}
    }

    final rawMeds = j['medications'] ?? j['items'];
    final meds = rawMeds is List
        ? rawMeds
            .map((e) => PrescriptionItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PrescriptionItem>[];

    return Prescription(
      id: (j['id'] as num?)?.toInt() ?? 0,
      customerId: (j['customer_id'] ?? j['customerId']) as int?,
      customerName: (j['customer_name'] ?? j['customerName'] as String?) ?? 'Walk-in',
      customerPhone: (j['customer_phone'] ?? j['customerPhone'] as String?) ?? '',
      doctorName: j['doctor_name'] ?? j['doctorName'] as String?,
      diagnosis: j['diagnosis'] as String?,
      notes: j['notes'] as String?,
      medications: meds,
      status: (j['status'] as String?) ?? 'pending',
      createdAt: formatted,
      dispensedAt: j['dispensed_at'] ?? j['dispensedAt'] as String?,
      createdByName: j['created_by_name'] ?? j['createdByName'] as String?,
      createdById: (j['created_by_id'] ?? j['createdById']) as int?,
      pharmacyName: j['pharmacy_name'] ?? j['pharmacyName'] as String?,
      pharmacyId: (j['pharmacy_id'] ?? j['pharmacyId']) as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        if (doctorName != null && doctorName!.isNotEmpty) 'doctor_name': doctorName,
        if (diagnosis != null && diagnosis!.isNotEmpty) 'diagnosis': diagnosis,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'medications': medications.map((m) => m.toJson()).toList(),
      };
}
