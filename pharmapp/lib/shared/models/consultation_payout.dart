/// Consultation-fee payout tracking.
///
/// A consultation fee is charged silently at POS (see [Prescription.consultationFee])
/// but is *owed to the prescriber*. Each dispensed prescription that carried a
/// consultation surcharge becomes one [ConsultationPayout] record the org-admin
/// settles, and the prescriber is notified of the running total paid out.
class ConsultationPayoutSummary {
  final double totalCollected; // all consultation fees attributed to prescriber
  final double pendingAmount;  // collected but not yet paid out
  final double paidAmount;     // already settled to prescriber
  final int pendingCount;
  final int paidCount;
  final int totalConsultations;

  const ConsultationPayoutSummary({
    required this.totalCollected,
    required this.pendingAmount,
    required this.paidAmount,
    required this.pendingCount,
    required this.paidCount,
    required this.totalConsultations,
  });

  factory ConsultationPayoutSummary.fromJson(Map<String, dynamic> j) =>
      ConsultationPayoutSummary(
        totalCollected:     ((j['total_collected'] ?? j['totalCollected']) as num?)?.toDouble() ?? 0.0,
        pendingAmount:      ((j['pending_amount'] ?? j['pendingAmount']) as num?)?.toDouble() ?? 0.0,
        paidAmount:         ((j['paid_amount'] ?? j['paidAmount']) as num?)?.toDouble() ?? 0.0,
        pendingCount:       ((j['pending_count'] ?? j['pendingCount']) as num?)?.toInt() ?? 0,
        paidCount:          ((j['paid_count'] ?? j['paidCount']) as num?)?.toInt() ?? 0,
        totalConsultations: ((j['total_consultations'] ?? j['totalConsultations']) as num?)?.toInt() ?? 0,
      );

  static const zero = ConsultationPayoutSummary(
    totalCollected: 0,
    pendingAmount: 0,
    paidAmount: 0,
    pendingCount: 0,
    paidCount: 0,
    totalConsultations: 0,
  );
}

class ConsultationPayout {
  final int id;
  final int prescriberId;
  final String prescriberName;
  final int prescriptionId;
  final String patientName;
  final String? category; // 'A'–'E' band, or null
  final double consultationFee;
  final String status; // 'pending' | 'paid'
  final String? paidAt;
  final String createdAt;

  const ConsultationPayout({
    required this.id,
    required this.prescriberId,
    required this.prescriberName,
    required this.prescriptionId,
    required this.patientName,
    this.category,
    required this.consultationFee,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  bool get isPaid => status == 'paid';

  factory ConsultationPayout.fromJson(Map<String, dynamic> j) {
    final rawDate = ((j['created_at'] ?? j['createdAt']) as String?) ?? '';
    String formatted = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        formatted = '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }
    return ConsultationPayout(
      id:              ((j['id']) as num?)?.toInt() ?? 0,
      prescriberId:    ((j['prescriber_id'] ?? j['prescriberId']) as num?)?.toInt() ?? 0,
      prescriberName:  ((j['prescriber_name'] ?? j['prescriberName']) as String?) ?? '',
      prescriptionId:  ((j['prescription_id'] ?? j['prescriptionId']) as num?)?.toInt() ?? 0,
      patientName:     ((j['patient_name'] ?? j['patientName']) as String?) ?? 'Unknown',
      category:        ((j['consultation_category'] ?? j['category']) as String?),
      consultationFee: ((j['consultation_fee'] ?? j['consultationFee']) as num?)?.toDouble() ?? 0.0,
      status:          (j['status'] as String?) ?? 'pending',
      paidAt:          ((j['paid_at'] ?? j['paidAt']) as String?),
      createdAt:       formatted,
    );
  }
}
