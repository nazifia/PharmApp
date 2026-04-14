import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../features/branches/providers/branch_provider.dart';
import 'reports_api_client.dart';

final reportsApiProvider = Provider<ReportsApiClient>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return ReportsApiClient.local();
  return ReportsApiClient.remote(ref.watch(dioProvider));
});

/// Returns the effective branch ID for report scoping.
/// null → org-wide (sentinel id == -1 means "All Branches").
int? _reportBranchId(Ref ref) {
  final b = ref.watch(activeBranchProvider);
  return (b != null && b.id > 0) ? b.id : null;
}

/// Sales report — keyed by period string: 'today' | 'week' | 'month' | 'year'
final salesReportProvider =
    FutureProvider.family<SalesReportData, String>((ref, period) {
  return ref.watch(reportsApiProvider).fetchSalesReport(
    period, branchId: _reportBranchId(ref),
  );
});

final inventoryReportProvider = FutureProvider<InventoryReportData>((ref) {
  return ref.watch(reportsApiProvider).fetchInventoryReport(
    branchId: _reportBranchId(ref),
  );
});

final customerReportProvider = FutureProvider<CustomerReportData>((ref) {
  return ref.watch(reportsApiProvider).fetchCustomerReport(
    branchId: _reportBranchId(ref),
  );
});

/// Profit report — keyed by period string
final profitReportProvider =
    FutureProvider.family<ProfitReportData, String>((ref, period) {
  return ref.watch(reportsApiProvider).fetchProfitReport(
    period, branchId: _reportBranchId(ref),
  );
});
