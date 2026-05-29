class CommissionSummary {
  final double totalEarned;
  final double pendingAmount;
  final double paidAmount;
  final int pendingCount;
  final int paidCount;
  final int totalPrescriptions;

  const CommissionSummary({
    required this.totalEarned,
    required this.pendingAmount,
    required this.paidAmount,
    required this.pendingCount,
    required this.paidCount,
    required this.totalPrescriptions,
  });

  factory CommissionSummary.fromJson(Map<String, dynamic> j) => CommissionSummary(
        totalEarned:        ((j['total_earned'] ?? j['totalEarned']) as num?)?.toDouble() ?? 0.0,
        pendingAmount:      ((j['pending_amount'] ?? j['pendingAmount']) as num?)?.toDouble() ?? 0.0,
        paidAmount:         ((j['paid_amount'] ?? j['paidAmount']) as num?)?.toDouble() ?? 0.0,
        pendingCount:       ((j['pending_count'] ?? j['pendingCount']) as num?)?.toInt() ?? 0,
        paidCount:          ((j['paid_count'] ?? j['paidCount']) as num?)?.toInt() ?? 0,
        totalPrescriptions: ((j['total_prescriptions'] ?? j['totalPrescriptions']) as num?)?.toInt() ?? 0,
      );

  static const zero = CommissionSummary(
    totalEarned: 0,
    pendingAmount: 0,
    paidAmount: 0,
    pendingCount: 0,
    paidCount: 0,
    totalPrescriptions: 0,
  );
}

class PrescriberCommission {
  final int id;
  final int prescriberId;
  final String prescriberName;
  final int prescriptionId;
  final String patientName;
  final double salesAmount;
  final double commissionRate;
  final double commissionAmount;
  final String status; // 'pending' | 'paid'
  final String? paidAt;
  final String createdAt;

  const PrescriberCommission({
    required this.id,
    required this.prescriberId,
    required this.prescriberName,
    required this.prescriptionId,
    required this.patientName,
    required this.salesAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  bool get isPaid => status == 'paid';

  factory PrescriberCommission.fromJson(Map<String, dynamic> j) {
    final rawDate = ((j['created_at'] ?? j['createdAt']) as String?) ?? '';
    String formatted = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        formatted = '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }
    return PrescriberCommission(
      id:               ((j['id']) as num?)?.toInt() ?? 0,
      prescriberId:     ((j['prescriber_id'] ?? j['prescriberId']) as num?)?.toInt() ?? 0,
      prescriberName:   ((j['prescriber_name'] ?? j['prescriberName']) as String?) ?? '',
      prescriptionId:   ((j['prescription_id'] ?? j['prescriptionId']) as num?)?.toInt() ?? 0,
      patientName:      ((j['patient_name'] ?? j['patientName']) as String?) ?? 'Unknown',
      salesAmount:      ((j['sales_amount'] ?? j['salesAmount']) as num?)?.toDouble() ?? 0.0,
      commissionRate:   ((j['commission_rate'] ?? j['commissionRate']) as num?)?.toDouble() ?? 0.0,
      commissionAmount: ((j['commission_amount'] ?? j['commissionAmount']) as num?)?.toDouble() ?? 0.0,
      status:           (j['status'] as String?) ?? 'pending',
      paidAt:           ((j['paid_at'] ?? j['paidAt']) as String?),
      createdAt:        formatted,
    );
  }
}
