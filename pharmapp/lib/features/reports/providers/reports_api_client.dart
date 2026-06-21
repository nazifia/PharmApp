import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db.dart';
import '../../../shared/models/commission_config.dart';

const _kSalesReportPrefix           = 'cache_report_sales_';
const _kInventoryReportKey          = 'cache_report_inventory';
const _kCustomerReportKey           = 'cache_report_customers';
const _kProfitReportPrefix          = 'cache_report_profit_';
const _kCashierSalesReportPrefix    = 'cache_report_cashier_sales_';
const _kCommissionConfigsKey        = 'cache_commission_configs';
const _kStaffPerformancePrefix      = 'cache_staff_performance_';

// ── Data models (unchanged) ────────────────────────────────────────────────────

class TopItem {
  final int itemId; final String name; final int qty; final double revenue;
  TopItem({required this.itemId, required this.name, required this.qty, required this.revenue});
  factory TopItem.fromJson(Map<String, dynamic> j) => TopItem(
        itemId: (j['itemId'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? 'Unknown',
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0);
}

/// One data point in a daily revenue breakdown (returned by week/month reports).
class DailySale {
  final String date;
  final double revenue;
  DailySale({required this.date, required this.revenue});
  factory DailySale.fromJson(Map<String, dynamic> j) => DailySale(
        date: (j['date'] as String?) ?? '',
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0);
}

class SalesReportData {
  final String period; final double totalRevenue; final double totalRetail;
  final double totalWholesale; final int totalSales; final List<TopItem> topItems;
  final List<DailySale> dailySales;
  /// Payment received per method: keys 'cash','pos','transfer','wallet'.
  final Map<String, double> paymentMethods;
  /// Today's payments per method — independent of the selected period.
  final Map<String, double> todayPaymentMethods;
  /// Expenses for the selected period by source: keys 'cash','other','total'.
  final Map<String, double> expenses;
  /// Period sales minus expenses, by till: keys 'cash','other','total'.
  final Map<String, double> net;
  SalesReportData({required this.period, required this.totalRevenue,
      required this.totalRetail, required this.totalWholesale,
      required this.totalSales, required this.topItems,
      this.dailySales = const [], this.paymentMethods = const {},
      this.todayPaymentMethods = const {},
      this.expenses = const {}, this.net = const {}});
  factory SalesReportData.fromJson(Map<String, dynamic> j) => SalesReportData(
        period: (j['period'] as String?) ?? 'month',
        totalRevenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
        totalRetail: (j['totalRetail'] as num?)?.toDouble() ?? 0,
        totalWholesale: (j['totalWholesale'] as num?)?.toDouble() ?? 0,
        totalSales: (j['totalSales'] as num?)?.toInt() ?? 0,
        topItems: (j['topItems'] as List? ?? [])
            .map((e) => TopItem.fromJson(e as Map<String, dynamic>)).toList(),
        dailySales: (j['dailyBreakdown'] as List? ?? [])
            .map((e) => DailySale.fromJson(e as Map<String, dynamic>)).toList(),
        paymentMethods: ((j['paymentMethods'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num?)?.toDouble() ?? 0)),
        todayPaymentMethods: ((j['todayPaymentMethods'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num?)?.toDouble() ?? 0)),
        expenses: ((j['expenses'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num?)?.toDouble() ?? 0)),
        net: ((j['net'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num?)?.toDouble() ?? 0)));
}

class LowStockItem {
  final int id; final String name; final int stock; final int lowStockThreshold;
  LowStockItem({required this.id, required this.name, required this.stock, required this.lowStockThreshold});
  factory LowStockItem.fromJson(Map<String, dynamic> j) => LowStockItem(
        id: (j['id'] as num).toInt(), name: j['name'] as String,
        stock: (j['stock'] as num).toInt(),
        lowStockThreshold: (j['lowStockThreshold'] as num).toInt());
}

class InventoryReportData {
  final int totalItems; final int lowStockCount; final double stockValue;
  final List<LowStockItem> lowStockItems;
  InventoryReportData({required this.totalItems, required this.lowStockCount,
      required this.stockValue, required this.lowStockItems});
  factory InventoryReportData.fromJson(Map<String, dynamic> j) => InventoryReportData(
        totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
        lowStockCount: (j['lowStockCount'] as num?)?.toInt() ?? 0,
        stockValue: (j['stockValue'] as num?)?.toDouble() ?? 0,
        lowStockItems: (j['lowStockItems'] as List? ?? [])
            .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>)).toList());
}

class TopCustomer {
  final int id; final String name; final double spent;
  TopCustomer({required this.id, required this.name, required this.spent});
  factory TopCustomer.fromJson(Map<String, dynamic> j) => TopCustomer(
        id: (j['id'] as num).toInt(), name: j['name'] as String,
        spent: (j['spent'] as num?)?.toDouble() ?? 0);
}

class CustomerReportData {
  final int total; final int retail; final int wholesale;
  final double totalDebt; final List<TopCustomer> topCustomers;
  CustomerReportData({required this.total, required this.retail,
      required this.wholesale, required this.totalDebt, required this.topCustomers});
  factory CustomerReportData.fromJson(Map<String, dynamic> j) => CustomerReportData(
        total: (j['total'] as num?)?.toInt() ?? 0,
        retail: (j['retail'] as num?)?.toInt() ?? 0,
        wholesale: (j['wholesale'] as num?)?.toInt() ?? 0,
        totalDebt: (j['totalDebt'] as num?)?.toDouble() ?? 0,
        topCustomers: (j['topCustomers'] as List? ?? [])
            .map((e) => TopCustomer.fromJson(e as Map<String, dynamic>)).toList());
}

class ProfitReportData {
  final String period; final double revenue; final double profit; final double margin;
  ProfitReportData({required this.period, required this.revenue,
      required this.profit, required this.margin});
  factory ProfitReportData.fromJson(Map<String, dynamic> j) => ProfitReportData(
        period: (j['period'] as String?) ?? 'month',
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
        profit: (j['profit'] as num?)?.toDouble() ?? 0,
        margin: (j['margin'] as num?)?.toDouble() ?? 0);
}

class CashierUserSummary {
  final String cashierId;
  final String cashierName;
  final int userId;
  final String role;
  final double totalAmount;
  final int totalSales;
  final double cashAmount;
  final double posAmount;
  final double transferAmount;
  final double walletAmount;

  CashierUserSummary({
    required this.cashierId, required this.cashierName,
    required this.userId, required this.role,
    required this.totalAmount, required this.totalSales,
    required this.cashAmount, required this.posAmount,
    required this.transferAmount, required this.walletAmount,
  });

  factory CashierUserSummary.fromJson(Map<String, dynamic> j) => CashierUserSummary(
    cashierId:      (j['cashierId'] as String?) ?? '',
    cashierName:    (j['cashierName'] as String?) ?? '',
    userId:         (j['userId'] as num?)?.toInt() ?? 0,
    role:           (j['role'] as String?) ?? '',
    totalAmount:    (j['totalAmount'] as num?)?.toDouble() ?? 0,
    totalSales:     (j['totalSales'] as num?)?.toInt() ?? 0,
    cashAmount:     (j['cashAmount'] as num?)?.toDouble() ?? 0,
    posAmount:      (j['posAmount'] as num?)?.toDouble() ?? 0,
    transferAmount: (j['transferAmount'] as num?)?.toDouble() ?? 0,
    walletAmount:   (j['walletAmount'] as num?)?.toDouble() ?? 0,
  );
}

class CashierSalesData {
  final String period;
  final String dateFrom;
  final String dateTo;
  final bool isAdminView;
  final double totalAmount;
  final int totalSales;
  final List<CashierUserSummary> users;

  CashierSalesData({
    required this.period, required this.dateFrom, required this.dateTo,
    required this.isAdminView, required this.totalAmount,
    required this.totalSales, required this.users,
  });

  factory CashierSalesData.fromJson(Map<String, dynamic> j) => CashierSalesData(
    period:      (j['period'] as String?) ?? 'today',
    dateFrom:    (j['dateFrom'] as String?) ?? '',
    dateTo:      (j['dateTo'] as String?) ?? '',
    isAdminView: (j['isAdminView'] as bool?) ?? false,
    totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0,
    totalSales:  (j['totalSales'] as num?)?.toInt() ?? 0,
    users:       (j['users'] as List? ?? [])
        .map((e) => CashierUserSummary.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

String? _detail(dynamic data) => data is Map ? data['detail'] as String? : null;

// ── API client ────────────────────────────────────────────────────────────────

class ReportsApiClient {
  final Dio? _dio;

  ReportsApiClient.local() : _dio = null;
  ReportsApiClient.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  /// Returns a cache-key segment for [branchId]: '_bN' or '' for org-wide.
  String _bs(int? branchId) =>
      (branchId != null && branchId > 0) ? '_b$branchId' : '';

  Future<SalesReportData> fetchSalesReport(String period, {int? branchId}) async {
    // Period may be 'today'|'week'|'month'|'year' or 'custom:yyyy-MM-dd:yyyy-MM-dd'
    final isCustom = period.startsWith('custom:');
    if (_isLocal) {
      return SalesReportData.fromJson(await LocalDb.instance.getSalesReport(period));
    }
    final cacheKey = '$_kSalesReportPrefix${_bs(branchId)}$period';
    try {
      final Map<String, dynamic> queryParams;
      if (isCustom) {
        final parts = period.split(':');
        queryParams = {'from': parts[1], 'to': parts[2]};
      } else {
        queryParams = {'period': period};
      }
      if (branchId != null && branchId > 0) queryParams['branch_id'] = branchId;
      final res = await _dio!.get('/reports/sales/', queryParameters: queryParams);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return SalesReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) return SalesReportData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return SalesReportData(period: period, totalRevenue: 0, totalRetail: 0, totalWholesale: 0, totalSales: 0, topItems: []);
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load sales report');
    }
  }

  Future<InventoryReportData> fetchInventoryReport({int? branchId}) async {
    if (_isLocal) return InventoryReportData.fromJson(await LocalDb.instance.getInventoryReport());
    final cacheKey = '$_kInventoryReportKey${_bs(branchId)}';
    try {
      final params = <String, dynamic>{};
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/reports/inventory/',
          queryParameters: params.isNotEmpty ? params : null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return InventoryReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) return InventoryReportData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return InventoryReportData(totalItems: 0, lowStockCount: 0, stockValue: 0, lowStockItems: []);
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load inventory report');
    }
  }

  Future<CustomerReportData> fetchCustomerReport({int? branchId}) async {
    if (_isLocal) return CustomerReportData.fromJson(await LocalDb.instance.getCustomerReport());
    final cacheKey = '$_kCustomerReportKey${_bs(branchId)}';
    try {
      final params = <String, dynamic>{};
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/reports/customers/',
          queryParameters: params.isNotEmpty ? params : null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return CustomerReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) return CustomerReportData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return CustomerReportData(total: 0, retail: 0, wholesale: 0, totalDebt: 0, topCustomers: []);
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load customer report');
    }
  }

  Future<ProfitReportData> fetchProfitReport(String period, {int? branchId}) async {
    if (_isLocal) return ProfitReportData.fromJson(await LocalDb.instance.getProfitReport(period));
    final cacheKey = '$_kProfitReportPrefix${_bs(branchId)}$period';
    try {
      final params = <String, dynamic>{'period': period};
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/reports/profit/', queryParameters: params);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return ProfitReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) return ProfitReportData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return ProfitReportData(period: period, revenue: 0, profit: 0, margin: 0);
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load profit report');
    }
  }

  Future<CashierSalesData> fetchCashierSalesReport(String period, {int? userId}) async {
    if (_isLocal) {
      return CashierSalesData(
        period: period, dateFrom: '', dateTo: '', isAdminView: false,
        totalAmount: 0, totalSales: 0, users: [],
      );
    }
    final userSeg = userId != null ? '_u$userId' : '';
    final cacheKey = '$_kCashierSalesReportPrefix$period$userSeg';
    try {
      final params = <String, dynamic>{'period': period};
      if (userId != null) params['user_id'] = userId;
      final res = await _dio!.get('/reports/cashier-sales/', queryParameters: params);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return CashierSalesData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) return CashierSalesData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return CashierSalesData(period: period, dateFrom: '', dateTo: '', isAdminView: false, totalAmount: 0, totalSales: 0, users: []);
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load cashier sales report');
    }
  }

  Future<List<CommissionConfig>> fetchCommissionConfigs() async {
    if (_isLocal) return [];
    try {
      final res = await _dio!.get('/commission-configs/');
      final list = res.data as List? ?? [];
      final configs = list
          .map((e) => CommissionConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCommissionConfigsKey, jsonEncode(res.data));
      return configs;
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kCommissionConfigsKey);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          return list
              .map((e) => CommissionConfig.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load commission configs');
    }
  }

  Future<CommissionConfig> updateCommissionConfig(
      int userId, double rate, double? bonus) async {
    if (_isLocal) {
      return CommissionConfig(
          userId: userId, userName: '', commissionRate: rate,
          fixedBonus: bonus, isActive: true);
    }
    try {
      final body = <String, dynamic>{
        'commission_rate': rate,
        if (bonus != null) 'fixed_bonus': bonus,
      };
      final res = await _dio!.patch('/commission-configs/$userId/', data: body);
      return CommissionConfig.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_detail(e.response?.data) ?? 'Failed to update commission config');
    }
  }

  Future<StaffPerformanceData> fetchStaffPerformance(String period) async {
    if (_isLocal) {
      return StaffPerformanceData(period: period, staff: [], totalCommissions: 0);
    }
    final cacheKey = '$_kStaffPerformancePrefix$period';
    try {
      final res = await _dio!.get(
          '/reports/staff-performance/', queryParameters: {'period': period});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return StaffPerformanceData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          return StaffPerformanceData.fromJson(
              jsonDecode(raw) as Map<String, dynamic>);
        }
        return StaffPerformanceData(period: period, staff: [], totalCommissions: 0);
      }
      throw Exception(_detail(e.response?.data) ?? 'Failed to load staff performance');
    }
  }
}
