import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/sale.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  POS API CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

class PosApiClient {
  final Dio _dio;
  PosApiClient(this._dio);

  Future<Map<String, dynamic>> submitCheckout(CheckoutPayload payload) async {
    final res = await _dio.post('/pos/checkout/', data: payload.toJson());
    return res.data as Map<String, dynamic>;
  }

  // ── Sales ──────────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchSales({String? from, String? to, int? customerId, String? search}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (customerId != null) params['customerId'] = customerId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/pos/sales/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchSaleDetail(int id) async {
    final res = await _dio.get('/pos/sales/$id/');
    return res.data as Map<String, dynamic>;
  }

  // ── Returns ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> returnItem(int saleId, {required int saleItemId, required int quantity, String refundMethod = 'wallet', String reason = ''}) async {
    final res = await _dio.post('/pos/sales/$saleId/return/', data: {
      'saleItemId': saleItemId, 'quantity': quantity,
      'refundMethod': refundMethod, 'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Payment Requests ──────────────────────────────────────────────────────
  Future<List<dynamic>> fetchPaymentRequests({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final res = await _dio.get('/pos/payment-requests/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendToCashier(List<Map<String, dynamic>> items, {int? customerId, int? cashierId, String paymentType = 'retail'}) async {
    final res = await _dio.post('/pos/payment-requests/send/', data: {
      'items': items, 'customerId': customerId,
      'cashierId': cashierId, 'paymentType': paymentType,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptPaymentRequest(int id) async {
    final res = await _dio.post('/pos/payment-requests/$id/accept/');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectPaymentRequest(int id) async {
    final res = await _dio.post('/pos/payment-requests/$id/reject/');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completePaymentRequest(int id, Map<String, dynamic> payment, String paymentMethod) async {
    final res = await _dio.post('/pos/payment-requests/$id/complete/', data: {
      'payment': payment, 'paymentMethod': paymentMethod,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Dispensing Log ─────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchDispensingLog({String? search, String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _dio.get('/pos/dispensing-log/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchDispensingStats() async {
    final res = await _dio.get('/pos/dispensing-stats/');
    return res.data as Map<String, dynamic>;
  }

  // ── Expenses ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchExpenseCategories() async {
    final res = await _dio.get('/pos/expense-categories/');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createExpenseCategory(String name) async {
    final res = await _dio.post('/pos/expense-categories/', data: {'name': name});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchExpenses({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _dio.get('/pos/expenses/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createExpense({required int categoryId, required double amount, String description = '', String? date}) async {
    final res = await _dio.post('/pos/expenses/', data: {
      'categoryId': categoryId, 'amount': amount,
      'description': description, 'date': date,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteExpense(int id) async {
    await _dio.delete('/pos/expenses/$id/');
  }

  Future<Map<String, dynamic>> fetchMonthlyReport({int? month, int? year}) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;
    final res = await _dio.get('/pos/monthly-report/', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchSuppliers({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/pos/suppliers/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSupplier({required String name, String phone = '', String contactInfo = ''}) async {
    final res = await _dio.post('/pos/suppliers/', data: {'name': name, 'phone': phone, 'contactInfo': contactInfo});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteSupplier(int id) async {
    await _dio.delete('/pos/suppliers/$id/');
  }

  // ── Procurements ───────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchProcurements({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/pos/procurements/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createProcurement({required int supplierId, required List<Map<String, dynamic>> items, String status = 'draft'}) async {
    final res = await _dio.post('/pos/procurements/', data: {'supplierId': supplierId, 'items': items, 'status': status});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeProcurement(int id) async {
    final res = await _dio.post('/pos/procurements/$id/complete/');
    return res.data as Map<String, dynamic>;
  }

  // ── Stock Checks ───────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchStockChecks() async {
    final res = await _dio.get('/pos/stock-checks/');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createStockCheck() async {
    final res = await _dio.post('/pos/stock-checks/');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchStockCheckDetail(int id) async {
    final res = await _dio.get('/pos/stock-checks/$id/');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addStockCheckItem(int checkId, int itemId) async {
    final res = await _dio.post('/pos/stock-checks/$checkId/add-item/', data: {'itemId': itemId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStockCheckItem(int checkId, int itemId, int actualQuantity, String itemStatus) async {
    final res = await _dio.post('/pos/stock-checks/$checkId/items/$itemId/', data: {'actualQuantity': actualQuantity, 'status': itemStatus});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveStockCheck(int id) async {
    final res = await _dio.post('/pos/stock-checks/$id/approve/');
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteStockCheck(int id) async {
    await _dio.delete('/pos/stock-checks/$id/delete/');
  }

  // ── Cashiers ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchCashiers() async {
    final res = await _dio.get('/pos/cashiers/');
    return res.data as List<dynamic>;
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchNotifications() async {
    final res = await _dio.get('/pos/notifications/');
    return res.data as List<dynamic>;
  }

  Future<int> fetchNotificationCount() async {
    final res = await _dio.get('/pos/notifications/count/');
    return (res.data['count'] as num).toInt();
  }

  Future<void> markNotificationRead(int id) async {
    await _dio.post('/pos/notifications/$id/read/');
  }

  // ── Barcode ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> lookupBarcode(String code) async {
    try {
      final res = await _dio.get('/pos/barcode/lookup/', queryParameters: {'code': code});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── User Management ───────────────────────────────────────────────────────
  Future<List<dynamic>> fetchUsers({String? search, String? role}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;
    final res = await _dio.get('/pos/users/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createUser({required String phoneNumber, required String password, String role = 'Cashier'}) async {
    final res = await _dio.post('/pos/users/', data: {'phoneNumber': phoneNumber, 'password': password, 'role': role});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteUser(int id) async {
    await _dio.delete('/pos/users/$id/');
  }

  Future<void> changePassword(int id, String newPassword) async {
    await _dio.post('/pos/users/$id/change-password/', data: {'newPassword': newPassword});
  }

  // ── Wholesale ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchWholesaleDashboard() async {
    final res = await _dio.get('/pos/wholesale/dashboard/');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchWholesaleCustomers({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/pos/wholesale/customers/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchWholesaleNegativeCustomers() async {
    final res = await _dio.get('/pos/wholesale/customers/negative/');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchWholesaleSales({String? from, String? to, String? search}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/pos/wholesale/sales/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchWholesaleSaleDetail(int id) async {
    final res = await _dio.get('/pos/wholesale/sales/$id/');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> returnWholesaleItem(int saleId, {required int saleItemId, required int quantity, String refundMethod = 'wallet', String reason = ''}) async {
    final res = await _dio.post('/pos/wholesale/sales/$saleId/return/', data: {
      'saleItemId': saleItemId, 'quantity': quantity,
      'refundMethod': refundMethod, 'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchWholesaleSalesByUser({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _dio.get('/pos/wholesale/sales/by-user/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchTransfers({String? status, String? direction}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (direction != null) params['direction'] = direction;
    final res = await _dio.get('/pos/wholesale/transfers/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTransfer({required String itemName, required int requestedQty, String unit = 'Pcs', bool fromWholesale = true, String notes = ''}) async {
    final res = await _dio.post('/pos/wholesale/transfers/', data: {'itemName': itemName, 'requestedQty': requestedQty, 'unit': unit, 'fromWholesale': fromWholesale, 'notes': notes});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveTransfer(int id, int approvedQty) async {
    final res = await _dio.post('/pos/wholesale/transfers/$id/approve/', data: {'approvedQty': approvedQty});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectTransfer(int id) async {
    final res = await _dio.post('/pos/wholesale/transfers/$id/reject/');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> receiveTransfer(int id) async {
    final res = await _dio.post('/pos/wholesale/transfers/$id/receive/');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchWholesaleLowStock({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/pos/wholesale/low-stock/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchWholesaleExpiryAlert() async {
    final res = await _dio.get('/pos/wholesale/expiry-alert/');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchWholesaleInventoryValue() async {
    final res = await _dio.get('/pos/wholesale/inventory-value/');
    return res.data as Map<String, dynamic>;
  }
}

final posApiProvider = Provider<PosApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return PosApiClient(dio);
});

// ═══════════════════════════════════════════════════════════════════════════════
//  CHECKOUT NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════════

class CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> processCheckout(CheckoutPayload payload) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(posApiProvider).submitCheckout(payload);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, AsyncValue<void>>((ref) {
  return CheckoutNotifier(ref);
});
