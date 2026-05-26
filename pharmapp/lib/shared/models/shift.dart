class Shift {
  final int id;
  final int staffId;
  final String staffName;
  final String? branchName;
  final String openedAt;
  final String? closedAt;
  final double openingCash;
  final double closingCash;
  final double totalSales;
  final double totalCash;
  final double totalPos;
  final double totalTransfer;
  final double totalWallet;
  final int salesCount;
  final String status; // 'open' | 'closed'

  const Shift({
    required this.id,
    required this.staffId,
    required this.staffName,
    this.branchName,
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    required this.closingCash,
    required this.totalSales,
    required this.totalCash,
    required this.totalPos,
    required this.totalTransfer,
    required this.totalWallet,
    required this.salesCount,
    required this.status,
  });

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id:           (j['id'] as num?)?.toInt() ?? 0,
        staffId:      (j['staff_id'] as num?)?.toInt() ?? 0,
        staffName:    (j['staff_name'] as String?) ?? '',
        branchName:   j['branch_name'] as String?,
        openedAt:     (j['opened_at'] as String?) ?? '',
        closedAt:     j['closed_at'] as String?,
        openingCash:  (j['opening_cash'] as num?)?.toDouble() ?? 0.0,
        closingCash:  (j['closing_cash'] as num?)?.toDouble() ?? 0.0,
        totalSales:   (j['total_sales'] as num?)?.toDouble() ?? 0.0,
        totalCash:    (j['total_cash'] as num?)?.toDouble() ?? 0.0,
        totalPos:     (j['total_pos'] as num?)?.toDouble() ?? 0.0,
        totalTransfer: (j['total_transfer'] as num?)?.toDouble() ?? 0.0,
        totalWallet:  (j['total_wallet'] as num?)?.toDouble() ?? 0.0,
        salesCount:   (j['sales_count'] as num?)?.toInt() ?? 0,
        status:       (j['status'] as String?) ?? 'closed',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'staff_id': staffId,
        'staff_name': staffName,
        if (branchName != null) 'branch_name': branchName,
        'opened_at': openedAt,
        if (closedAt != null) 'closed_at': closedAt,
        'opening_cash': openingCash,
        'closing_cash': closingCash,
        'total_sales': totalSales,
        'total_cash': totalCash,
        'total_pos': totalPos,
        'total_transfer': totalTransfer,
        'total_wallet': totalWallet,
        'sales_count': salesCount,
        'status': status,
      };
}
