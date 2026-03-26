import 'package:dio/dio.dart';
import '../../../core/database/local_db.dart';

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

class SalesReportData {
  final String period; final double totalRevenue; final double totalRetail;
  final double totalWholesale; final int totalSales; final List<TopItem> topItems;
  SalesReportData({required this.period, required this.totalRevenue,
      required this.totalRetail, required this.totalWholesale,
      required this.totalSales, required this.topItems});
  factory SalesReportData.fromJson(Map<String, dynamic> j) => SalesReportData(
        period: (j['period'] as String?) ?? 'month',
        totalRevenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
        totalRetail: (j['totalRetail'] as num?)?.toDouble() ?? 0,
        totalWholesale: (j['totalWholesale'] as num?)?.toDouble() ?? 0,
        totalSales: (j['totalSales'] as num?)?.toInt() ?? 0,
        topItems: (j['topItems'] as List? ?? [])
            .map((e) => TopItem.fromJson(e as Map<String, dynamic>)).toList());
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

// ── API client ────────────────────────────────────────────────────────────────

class ReportsApiClient {
  final Dio? _dio;

  ReportsApiClient.local() : _dio = null;
  ReportsApiClient.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  Future<SalesReportData> fetchSalesReport(String period) async {
    // Period may be 'today'|'week'|'month'|'year' or 'custom:yyyy-MM-dd:yyyy-MM-dd'
    final isCustom = period.startsWith('custom:');
    if (_isLocal) {
      return SalesReportData.fromJson(await LocalDb.instance.getSalesReport(period));
    }
    try {
      final Map<String, dynamic> queryParams;
      if (isCustom) {
        final parts = period.split(':');
        queryParams = {'from': parts[1], 'to': parts[2]};
      } else {
        queryParams = {'period': period};
      }
      final res = await _dio!.get('/reports/sales/', queryParameters: queryParams);
      return SalesReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load sales report');
    }
  }

  Future<InventoryReportData> fetchInventoryReport() async {
    if (_isLocal) return InventoryReportData.fromJson(await LocalDb.instance.getInventoryReport());
    try {
      final res = await _dio!.get('/reports/inventory/');
      return InventoryReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load inventory report');
    }
  }

  Future<CustomerReportData> fetchCustomerReport() async {
    if (_isLocal) return CustomerReportData.fromJson(await LocalDb.instance.getCustomerReport());
    try {
      final res = await _dio!.get('/reports/customers/');
      return CustomerReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customer report');
    }
  }

  Future<ProfitReportData> fetchProfitReport(String period) async {
    if (_isLocal) return ProfitReportData.fromJson(await LocalDb.instance.getProfitReport(period));
    try {
      final res = await _dio!.get('/reports/profit/', queryParameters: {'period': period});
      return ProfitReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load profit report');
    }
  }
}
