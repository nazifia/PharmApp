import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'reports_api_client.dart';

final reportsApiProvider = Provider<ReportsApiClient>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return ReportsApiClient.local();
  return ReportsApiClient.remote(ref.watch(dioProvider));
});

/// Sales report — keyed by period string: 'today' | 'week' | 'month' | 'year'
final salesReportProvider =
    FutureProvider.family<SalesReportData, String>((ref, period) {
  return ref.watch(reportsApiProvider).fetchSalesReport(period);
});

final inventoryReportProvider = FutureProvider<InventoryReportData>((ref) {
  return ref.watch(reportsApiProvider).fetchInventoryReport();
});

final customerReportProvider = FutureProvider<CustomerReportData>((ref) {
  return ref.watch(reportsApiProvider).fetchCustomerReport();
});

/// Profit report — keyed by period string
final profitReportProvider =
    FutureProvider.family<ProfitReportData, String>((ref, period) {
  return ref.watch(reportsApiProvider).fetchProfitReport(period);
});
