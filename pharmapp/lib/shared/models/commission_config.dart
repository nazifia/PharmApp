class CommissionConfig {
  final int userId;
  final String userName;
  final double commissionRate;
  final double? fixedBonus;
  final bool isActive;

  CommissionConfig({
    required this.userId,
    required this.userName,
    required this.commissionRate,
    this.fixedBonus,
    required this.isActive,
  });

  factory CommissionConfig.fromJson(Map<String, dynamic> j) => CommissionConfig(
        userId:         ((j['userId'] ?? j['user_id']) as num?)?.toInt() ?? 0,
        userName:       (j['userName'] ?? j['user_name']) as String? ?? '',
        commissionRate: ((j['commissionRate'] ?? j['commission_rate']) as num?)?.toDouble() ?? 0,
        fixedBonus:     ((j['fixedBonus'] ?? j['fixed_bonus']) as num?)?.toDouble(),
        isActive:       (j['isActive'] ?? j['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'userId':         userId,
        'userName':       userName,
        'commissionRate': commissionRate,
        if (fixedBonus != null) 'fixedBonus': fixedBonus,
        'isActive':       isActive,
      };
}

class StaffPerformanceEntry {
  final int userId;
  final String userName;
  final String role;
  final int salesCount;
  final double totalSales;
  final double commissionRate;
  final double? fixedBonus;

  StaffPerformanceEntry({
    required this.userId,
    required this.userName,
    required this.role,
    required this.salesCount,
    required this.totalSales,
    required this.commissionRate,
    this.fixedBonus,
  });

  double get commissionEarned => totalSales * commissionRate;
  double get totalPayout      => commissionEarned + (fixedBonus ?? 0);

  factory StaffPerformanceEntry.fromJson(Map<String, dynamic> j) =>
      StaffPerformanceEntry(
        userId:         ((j['userId'] ?? j['user_id']) as num?)?.toInt() ?? 0,
        userName:       (j['userName'] ?? j['user_name']) as String? ?? '',
        role:           (j['role'] as String?) ?? '',
        salesCount:     ((j['salesCount'] ?? j['sales_count']) as num?)?.toInt() ?? 0,
        totalSales:     ((j['totalSales'] ?? j['total_sales']) as num?)?.toDouble() ?? 0,
        commissionRate: ((j['commissionRate'] ?? j['commission_rate']) as num?)?.toDouble() ?? 0,
        fixedBonus:     ((j['fixedBonus'] ?? j['fixed_bonus']) as num?)?.toDouble(),
      );
}

class StaffPerformanceData {
  final String period;
  final List<StaffPerformanceEntry> staff;
  final double totalCommissions;

  StaffPerformanceData({
    required this.period,
    required this.staff,
    required this.totalCommissions,
  });

  factory StaffPerformanceData.fromJson(Map<String, dynamic> j) =>
      StaffPerformanceData(
        period:           (j['period'] as String?) ?? 'today',
        totalCommissions: ((j['totalCommissions'] ?? j['total_commissions']) as num?)?.toDouble() ?? 0,
        staff: (j['staff'] as List? ?? [])
            .map((e) => StaffPerformanceEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
