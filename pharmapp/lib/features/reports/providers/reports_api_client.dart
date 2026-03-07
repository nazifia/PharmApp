import 'package:dio/dio.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class DailySale {
  final String label;
  final double retail;
  final double wholesale;
  DailySale({required this.label, required this.retail, required this.wholesale});
  factory DailySale.fromJson(Map<String, dynamic> j) => DailySale(
        label:     j['label']     as String,
        retail:    (j['retail']   as num).toDouble(),
        wholesale: (j['wholesale'] as num).toDouble(),
      );
}

class TopItem {
  final String name;
  final int qty;
  final double revenue;
  TopItem({required this.name, required this.qty, required this.revenue});
  factory TopItem.fromJson(Map<String, dynamic> j) => TopItem(
        name:    j['name']    as String,
        qty:     (j['qty']    as num).toInt(),
        revenue: (j['revenue'] as num).toDouble(),
      );
}

class SalesReportData {
  final double totalRetail;
  final double totalWholesale;
  final List<DailySale> daily;
  final List<TopItem> topItems;
  SalesReportData({required this.totalRetail, required this.totalWholesale,
      required this.daily, required this.topItems});
  factory SalesReportData.fromJson(Map<String, dynamic> j) => SalesReportData(
        totalRetail:    (j['total_retail']    as num?)?.toDouble() ?? 0,
        totalWholesale: (j['total_wholesale'] as num?)?.toDouble() ?? 0,
        daily:    (j['daily_breakdown'] as List? ?? [])
            .map((e) => DailySale.fromJson(e as Map<String, dynamic>)).toList(),
        topItems: (j['top_items'] as List? ?? [])
            .map((e) => TopItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class CategoryStock {
  final String name;
  final int skus;
  final double value;
  final double pct;
  CategoryStock({required this.name, required this.skus, required this.value, required this.pct});
  factory CategoryStock.fromJson(Map<String, dynamic> j) => CategoryStock(
        name: j['name'] as String,
        skus: (j['skus'] as num).toInt(),
        value: (j['value'] as num).toDouble(),
        pct:   (j['pct']   as num).toDouble(),
      );
}

class LowStockItem {
  final String name;
  final int stock;
  final int low;
  final int reorder;
  LowStockItem({required this.name, required this.stock, required this.low, required this.reorder});
  factory LowStockItem.fromJson(Map<String, dynamic> j) => LowStockItem(
        name:    j['name']    as String,
        stock:   (j['stock']   as num).toInt(),
        low:     (j['low']     as num).toInt(),
        reorder: (j['reorder'] as num).toInt(),
      );
}

class InventoryReportData {
  final int totalSkus;
  final int lowStock;
  final int outOfStock;
  final int expiringSoon;
  final double stockValue;
  final int categories;
  final List<CategoryStock> categoryBreakdown;
  final List<LowStockItem> lowStockItems;
  InventoryReportData({required this.totalSkus, required this.lowStock,
      required this.outOfStock, required this.expiringSoon,
      required this.stockValue, required this.categories,
      required this.categoryBreakdown, required this.lowStockItems});
  factory InventoryReportData.fromJson(Map<String, dynamic> j) =>
      InventoryReportData(
        totalSkus:    (j['total_skus']    as num?)?.toInt()    ?? 0,
        lowStock:     (j['low_stock']     as num?)?.toInt()    ?? 0,
        outOfStock:   (j['out_of_stock']  as num?)?.toInt()    ?? 0,
        expiringSoon: (j['expiring_soon'] as num?)?.toInt()    ?? 0,
        stockValue:   (j['stock_value']   as num?)?.toDouble() ?? 0,
        categories:   (j['categories']    as num?)?.toInt()    ?? 0,
        categoryBreakdown: (j['category_breakdown'] as List? ?? [])
            .map((e) => CategoryStock.fromJson(e as Map<String, dynamic>)).toList(),
        lowStockItems: (j['low_stock_items'] as List? ?? [])
            .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class TopCustomer {
  final String name;
  final int purchases;
  final double spent;
  final double debt;
  TopCustomer({required this.name, required this.purchases, required this.spent, required this.debt});
  factory TopCustomer.fromJson(Map<String, dynamic> j) => TopCustomer(
        name:      j['name']      as String,
        purchases: (j['purchases'] as num).toInt(),
        spent:     (j['spent']     as num).toDouble(),
        debt:      (j['debt']      as num? ?? 0).toDouble(),
      );
}

class CustomerReportData {
  final int total;
  final int retail;
  final int wholesale;
  final double totalDebt;
  final double totalWallet;
  final List<TopCustomer> topCustomers;
  CustomerReportData({required this.total, required this.retail,
      required this.wholesale, required this.totalDebt,
      required this.totalWallet, required this.topCustomers});
  factory CustomerReportData.fromJson(Map<String, dynamic> j) =>
      CustomerReportData(
        total:        (j['total']         as num?)?.toInt()    ?? 0,
        retail:       (j['retail']        as num?)?.toInt()    ?? 0,
        wholesale:    (j['wholesale']     as num?)?.toInt()    ?? 0,
        totalDebt:    (j['total_debt']    as num?)?.toDouble() ?? 0,
        totalWallet:  (j['total_wallet']  as num?)?.toDouble() ?? 0,
        topCustomers: (j['top_customers'] as List? ?? [])
            .map((e) => TopCustomer.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class CategoryProfit {
  final String name;
  final double revenue;
  final double cost;
  final double margin;
  CategoryProfit({required this.name, required this.revenue, required this.cost, required this.margin});
  factory CategoryProfit.fromJson(Map<String, dynamic> j) => CategoryProfit(
        name:    j['name']    as String,
        revenue: (j['revenue'] as num).toDouble(),
        cost:    (j['cost']    as num).toDouble(),
        margin:  (j['margin']  as num).toDouble(),
      );
}

class ProfitReportData {
  final double revenue;
  final double cost;
  final double grossProfit;
  final double netMargin;
  final List<CategoryProfit> byCategory;
  ProfitReportData({required this.revenue, required this.cost,
      required this.grossProfit, required this.netMargin, required this.byCategory});
  factory ProfitReportData.fromJson(Map<String, dynamic> j) => ProfitReportData(
        revenue:     (j['revenue']      as num?)?.toDouble() ?? 0,
        cost:        (j['cost']         as num?)?.toDouble() ?? 0,
        grossProfit: (j['gross_profit'] as num?)?.toDouble() ?? 0,
        netMargin:   (j['net_margin']   as num?)?.toDouble() ?? 0,
        byCategory:  (j['by_category']  as List? ?? [])
            .map((e) => CategoryProfit.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

// ── API client ─────────────────────────────────────────────────────────────────

class ReportsApiClient {
  final Dio _dio;
  ReportsApiClient(this._dio);

  Future<SalesReportData> fetchSalesReport(String period) async {
    try {
      final res = await _dio.get('/reports/sales/', queryParameters: {'period': period});
      return SalesReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load sales report');
    }
  }

  Future<InventoryReportData> fetchInventoryReport() async {
    try {
      final res = await _dio.get('/reports/inventory/');
      return InventoryReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load inventory report');
    }
  }

  Future<CustomerReportData> fetchCustomerReport() async {
    try {
      final res = await _dio.get('/reports/customers/');
      return CustomerReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customer report');
    }
  }

  Future<ProfitReportData> fetchProfitReport(String period) async {
    try {
      final res = await _dio.get('/reports/profit/', queryParameters: {'period': period});
      return ProfitReportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load profit report');
    }
  }
}
