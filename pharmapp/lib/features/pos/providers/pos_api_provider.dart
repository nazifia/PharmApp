import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/local_db.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/sale.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  POS API CLIENT — dev (local SQLite) + prod (Django REST)
// ═══════════════════════════════════════════════════════════════════════════════

class PosApiClient {
  final Dio? _dio;

  PosApiClient.local() : _dio = null;
  PosApiClient.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  // ── Sales ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> submitCheckout(CheckoutPayload payload) async {
    if (_isLocal) {
      // Explicitly deep-serialize nested models — freezed toJson() does not
      // convert List<SaleItemPayload> or PaymentPayload to Map automatically.
      return LocalDb.instance.createSale({
        'items': payload.items.map((i) => i.toJson()).toList(),
        'payment': payload.payment.toJson(),
        'customerId': payload.customerId,
        'isWholesale': payload.isWholesale,
        'paymentMethod': payload.paymentMethod,
        'totalAmount': payload.totalAmount,
      });
    }
    try {
      final res = await _dio!.post('/pos/checkout/', data: payload.toJson());
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Checkout failed');
    }
  }

  Future<List<dynamic>> fetchSales(
      {String? from, String? to, int? customerId, String? search}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getSales(from: from, to: to, customerId: customerId, search: search);
    }
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (customerId != null) params['customer_id'] = customerId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio!.get('/pos/sales/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load sales');
    }
  }

  Future<Map<String, dynamic>> fetchSaleDetail(int id) async {
    if (_isLocal) {
      final r = await LocalDb.instance.getSaleDetail(id);
      if (r == null) throw Exception('Sale not found');
      return r;
    }
    try {
      final res = await _dio!.get('/pos/sales/$id/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Sale not found');
    }
  }

  // ── Returns ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> returnItem(int saleId,
      {required int saleItemId,
      required int quantity,
      String refundMethod = 'wallet',
      String reason = ''}) async {
    if (_isLocal) {
      return LocalDb.instance.returnSaleItem(saleId,
          saleItemId: saleItemId,
          quantity: quantity,
          refundMethod: refundMethod,
          reason: reason);
    }
    try {
      final res = await _dio!.post('/pos/sales/$saleId/return-item/', data: {
        'sale_item_id': saleItemId,
        'quantity': quantity,
        'refund_method': refundMethod,
        'reason': reason,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Return failed');
    }
  }

  // ── Payment Requests ───────────────────────────────────────────────────────
  Future<List<dynamic>> fetchPaymentRequests({String? status}) async {
    if (_isLocal) return LocalDb.instance.getPaymentRequests(status: status);
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      final res = await _dio!.get('/pos/payment-requests/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load payment requests');
    }
  }

  Future<Map<String, dynamic>> sendToCashier(
      List<Map<String, dynamic>> items,
      {int? customerId,
      int? cashierId,
      String paymentType = 'retail'}) async {
    if (_isLocal) {
      return LocalDb.instance.createPaymentRequest(items,
          customerId: customerId,
          cashierId: cashierId,
          paymentType: paymentType);
    }
    try {
      final res = await _dio!.post('/pos/payment-requests/', data: {
        'items': items,
        if (customerId != null) 'customer_id': customerId,
        if (cashierId != null) 'cashier_id': cashierId,
        'payment_type': paymentType,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to send to cashier');
    }
  }

  Future<Map<String, dynamic>> acceptPaymentRequest(int id) async {
    if (_isLocal) {
      return LocalDb.instance.updatePaymentRequestStatus(id, 'accepted');
    }
    try {
      final res = await _dio!.post('/pos/payment-requests/$id/accept/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to accept request');
    }
  }

  Future<Map<String, dynamic>> rejectPaymentRequest(int id) async {
    if (_isLocal) {
      return LocalDb.instance.updatePaymentRequestStatus(id, 'rejected');
    }
    try {
      final res = await _dio!.post('/pos/payment-requests/$id/reject/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to reject request');
    }
  }

  Future<Map<String, dynamic>> completePaymentRequest(
      int id, Map<String, dynamic> payment, String paymentMethod) async {
    if (_isLocal) {
      return LocalDb.instance.updatePaymentRequestStatus(id, 'completed');
    }
    try {
      final res = await _dio!.post('/pos/payment-requests/$id/complete/',
          data: {'payment': payment, 'payment_method': paymentMethod});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to complete payment request');
    }
  }

  // ── Dispensing Log ─────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchDispensingLog(
      {String? search, String? from, String? to}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getDispensingLog(search: search, from: from, to: to);
    }
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await _dio!.get('/pos/dispensing-log/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load dispensing log');
    }
  }

  Future<Map<String, dynamic>> fetchDispensingStats() async {
    if (_isLocal) return LocalDb.instance.getDispensingStats();
    try {
      final res = await _dio!.get('/pos/dispensing-log/stats/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load dispensing stats');
    }
  }

  // ── Expenses ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchExpenseCategories() async {
    if (_isLocal) return LocalDb.instance.getExpenseCategories();
    try {
      final res = await _dio!.get('/pos/expense-categories/');
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load expense categories');
    }
  }

  Future<Map<String, dynamic>> createExpenseCategory(String name) async {
    if (_isLocal) return LocalDb.instance.createExpenseCategory(name);
    try {
      final res =
          await _dio!.post('/pos/expense-categories/', data: {'name': name});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create expense category');
    }
  }

  Future<List<dynamic>> fetchExpenses({String? from, String? to}) async {
    if (_isLocal) return LocalDb.instance.getExpenses(from: from, to: to);
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await _dio!.get('/pos/expenses/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load expenses');
    }
  }

  Future<Map<String, dynamic>> createExpense({
    required int categoryId,
    required double amount,
    String description = '',
    String? date,
  }) async {
    if (_isLocal) {
      return LocalDb.instance.createExpense(
          categoryId: categoryId,
          amount: amount,
          description: description,
          date: date);
    }
    try {
      final res = await _dio!.post('/pos/expenses/', data: {
        'category_id': categoryId,
        'amount': amount,
        'description': description,
        if (date != null) 'date': date,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create expense');
    }
  }

  Future<void> deleteExpense(int id) async {
    if (_isLocal) return LocalDb.instance.deleteExpense(id);
    try {
      await _dio!.delete('/pos/expenses/$id/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete expense');
    }
  }

  Future<Map<String, dynamic>> fetchMonthlyReport(
      {int? month, int? year}) async {
    if (_isLocal) {
      return LocalDb.instance.getMonthlyReport(month: month, year: year);
    }
    try {
      final params = <String, dynamic>{};
      if (month != null) params['month'] = month;
      if (year != null) params['year'] = year;
      final res = await _dio!.get('/pos/monthly-report/',
          queryParameters: params.isNotEmpty ? params : null);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load monthly report');
    }
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchSuppliers({String? search}) async {
    if (_isLocal) return LocalDb.instance.getSuppliers(search: search);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio!.get('/pos/suppliers/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load suppliers');
    }
  }

  Future<Map<String, dynamic>> createSupplier({
    required String name,
    String phone = '',
    String contactInfo = '',
  }) async {
    if (_isLocal) {
      return LocalDb.instance
          .createSupplier(name, phone: phone, contactInfo: contactInfo);
    }
    try {
      final res = await _dio!.post('/pos/suppliers/', data: {
        'name': name,
        'phone': phone,
        'contact_info': contactInfo,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create supplier');
    }
  }

  Future<void> deleteSupplier(int id) async {
    if (_isLocal) return LocalDb.instance.deleteSupplier(id);
    try {
      await _dio!.delete('/pos/suppliers/$id/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete supplier');
    }
  }

  // ── Procurements ───────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchProcurements({String? search}) async {
    if (_isLocal) return LocalDb.instance.getProcurements(search: search);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio!.get('/pos/procurements/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load procurements');
    }
  }

  Future<Map<String, dynamic>> createProcurement({
    required int supplierId,
    required List<Map<String, dynamic>> items,
    String status = 'draft',
    String destination = 'retail',
  }) async {
    if (_isLocal) {
      return LocalDb.instance.createProcurement(
          supplierId: supplierId,
          items: items,
          status: status,
          destination: destination);
    }
    try {
      final res = await _dio!.post('/pos/procurements/', data: {
        'supplier_id': supplierId,
        'items': items,
        'status': status,
        'destination': destination,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create procurement');
    }
  }

  Future<Map<String, dynamic>> completeProcurement(int id,
      {String destination = 'retail'}) async {
    if (_isLocal) {
      return LocalDb.instance
          .completeProcurement(id, destination: destination);
    }
    try {
      final res = await _dio!.post('/pos/procurements/$id/complete/',
          data: {'destination': destination});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to complete procurement');
    }
  }

  // ── Stock Checks ───────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchStockChecks() async {
    if (_isLocal) return LocalDb.instance.getStockChecks();
    try {
      final res = await _dio!.get('/pos/stock-checks/');
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load stock checks');
    }
  }

  Future<Map<String, dynamic>> createStockCheck() async {
    if (_isLocal) return LocalDb.instance.createStockCheck();
    try {
      final res = await _dio!.post('/pos/stock-checks/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create stock check');
    }
  }

  Future<Map<String, dynamic>> fetchStockCheckDetail(int id) async {
    if (_isLocal) return LocalDb.instance.getStockCheckDetail(id);
    try {
      final res = await _dio!.get('/pos/stock-checks/$id/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Stock check not found');
    }
  }

  Future<Map<String, dynamic>> addStockCheckItem(
      int checkId, int itemId) async {
    if (_isLocal) {
      return LocalDb.instance.addStockCheckItem(checkId, itemId);
    }
    try {
      final res = await _dio!
          .post('/pos/stock-checks/$checkId/items/', data: {'item_id': itemId});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to add stock check item');
    }
  }

  Future<Map<String, dynamic>> updateStockCheckItem(
      int checkId, int itemId, int actualQuantity, String itemStatus) async {
    if (_isLocal) {
      return LocalDb.instance
          .updateStockCheckItem(checkId, itemId, actualQuantity, itemStatus);
    }
    try {
      final res = await _dio!
          .patch('/pos/stock-checks/$checkId/items/$itemId/', data: {
        'actual_quantity': actualQuantity,
        'status': itemStatus,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to update stock check item');
    }
  }

  Future<Map<String, dynamic>> approveStockCheck(int id) async {
    if (_isLocal) return LocalDb.instance.approveStockCheck(id);
    try {
      final res = await _dio!.post('/pos/stock-checks/$id/approve/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to approve stock check');
    }
  }

  Future<void> deleteStockCheck(int id) async {
    if (_isLocal) return LocalDb.instance.deleteStockCheck(id);
    try {
      await _dio!.delete('/pos/stock-checks/$id/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete stock check');
    }
  }

  // ── Cashiers ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchCashiers() async {
    if (_isLocal) return LocalDb.instance.getAllUsers(role: 'Cashier');
    try {
      final res =
          await _dio!.get('/users/', queryParameters: {'role': 'Cashier'});
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load cashiers');
    }
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchNotifications() async {
    if (_isLocal) return LocalDb.instance.getNotifications();
    try {
      final res = await _dio!.get('/notifications/');
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load notifications');
    }
  }

  Future<int> fetchNotificationCount() async {
    if (_isLocal) return LocalDb.instance.getUnreadCount();
    try {
      final res = await _dio!.get('/notifications/count/');
      return (res.data['count'] as num?)?.toInt() ?? 0;
    } on DioException catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead(int id) async {
    if (_isLocal) return LocalDb.instance.markNotificationRead(id);
    try {
      await _dio!.post('/notifications/$id/read/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to mark notification read');
    }
  }

  // ── Barcode ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> lookupBarcode(String code) async {
    if (_isLocal) return LocalDb.instance.getItemByBarcode(code);
    try {
      final res = await _dio!
          .get('/inventory/items/', queryParameters: {'barcode': code});
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list.isEmpty ? null : list[0] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── User Management ────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchUsers({String? search, String? role}) async {
    if (_isLocal) {
      return LocalDb.instance.getAllUsers(search: search, role: role);
    }
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (role != null && role.isNotEmpty) params['role'] = role;
      final res = await _dio!.get('/users/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load users');
    }
  }

  Future<Map<String, dynamic>> createUser({
    required String phoneNumber,
    required String password,
    String role = 'Cashier',
    String username = '',
  }) async {
    if (_isLocal) {
      return LocalDb.instance.createUser(phoneNumber, password, role, username: username);
    }
    try {
      final res = await _dio!.post('/users/', data: {
        'phone_number': phoneNumber,
        'password': password,
        'role': role,
        'username': username,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create user');
    }
  }

  Future<void> deleteUser(int id) async {
    if (_isLocal) return LocalDb.instance.deleteUser(id);
    try {
      await _dio!.delete('/users/$id/');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete user');
    }
  }

  Future<void> changePassword(int id, String newPassword) async {
    if (_isLocal) {
      return LocalDb.instance.changeUserPassword(id, newPassword);
    }
    try {
      await _dio!.post('/users/$id/change-password/',
          data: {'new_password': newPassword});
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to change password');
    }
  }

  Future<Map<String, dynamic>> updateUser(int id,
      {String? role, bool? isActive, String? username}) async {
    if (_isLocal) {
      return LocalDb.instance.updateUser(id, role: role, isActive: isActive, username: username);
    }
    try {
      final data = <String, dynamic>{};
      if (role != null) data['role'] = role;
      if (isActive != null) data['is_active'] = isActive;
      if (username != null) data['username'] = username;
      final res = await _dio!.patch('/users/$id/', data: data);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update user');
    }
  }

  // ── Wholesale ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchWholesaleDashboard() async {
    if (_isLocal) return LocalDb.instance.getWholesaleDashboard();
    try {
      final res = await _dio!.get('/wholesale/dashboard/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load wholesale dashboard');
    }
  }

  Future<List<dynamic>> fetchWholesaleCustomers({String? search}) async {
    if (_isLocal) {
      final all = await LocalDb.instance.getCustomers();
      final wholesale = all.where((c) => c['isWholesale'] == true).toList();
      if (search != null && search.isNotEmpty) {
        return wholesale
            .where((c) =>
                (c['name'] as String)
                    .toLowerCase()
                    .contains(search.toLowerCase()))
            .toList();
      }
      return wholesale;
    }
    try {
      final params = <String, dynamic>{'wholesale': 'true'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio!.get('/customers/', queryParameters: params);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load wholesale customers');
    }
  }

  Future<List<dynamic>> fetchWholesaleNegativeCustomers() async {
    if (_isLocal) {
      final all = await LocalDb.instance.getCustomers();
      return all
          .where((c) =>
              c['isWholesale'] == true &&
              (c['walletBalance'] as double) < 0)
          .toList();
    }
    try {
      final res = await _dio!.get('/customers/',
          queryParameters: {'wholesale': 'true', 'negative_balance': 'true'});
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load customers');
    }
  }

  Future<List<dynamic>> fetchWholesaleSales(
      {String? from, String? to, String? search}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getSales(from: from, to: to, search: search, isWholesale: true);
    }
    try {
      final params = <String, dynamic>{'wholesale': 'true'};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio!.get('/pos/sales/', queryParameters: params);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load wholesale sales');
    }
  }

  Future<Map<String, dynamic>> fetchWholesaleSaleDetail(int id) async {
    if (_isLocal) {
      final r = await LocalDb.instance.getSaleDetail(id);
      if (r == null) throw Exception('Sale not found');
      return r;
    }
    try {
      final res = await _dio!.get('/pos/sales/$id/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Sale not found');
    }
  }

  Future<Map<String, dynamic>> returnWholesaleItem(int saleId,
      {required int saleItemId,
      required int quantity,
      String refundMethod = 'wallet',
      String reason = ''}) async {
    if (_isLocal) {
      return LocalDb.instance.returnSaleItem(saleId,
          saleItemId: saleItemId,
          quantity: quantity,
          refundMethod: refundMethod,
          reason: reason);
    }
    try {
      final res = await _dio!.post('/pos/sales/$saleId/return-item/', data: {
        'sale_item_id': saleItemId,
        'quantity': quantity,
        'refund_method': refundMethod,
        'reason': reason,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Return failed');
    }
  }

  Future<List<dynamic>> fetchWholesaleSalesByUser(
      {String? from, String? to}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getSales(from: from, to: to, isWholesale: true);
    }
    try {
      final params = <String, dynamic>{'wholesale': 'true'};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await _dio!.get('/pos/sales/', queryParameters: params);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load wholesale sales');
    }
  }

  // ── Transfers ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchTransfers(
      {String? status, String? direction}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getTransfers(status: status, direction: direction);
    }
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (direction != null) params['direction'] = direction;
      final res = await _dio!.get('/pos/wholesale/transfers/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load transfers');
    }
  }

  Future<Map<String, dynamic>> createTransfer({
    required String itemName,
    required int requestedQty,
    String unit = 'Pcs',
    bool fromWholesale = true,
    String notes = '',
  }) async {
    if (_isLocal) {
      return LocalDb.instance.createTransfer(
          itemName: itemName,
          requestedQty: requestedQty,
          unit: unit,
          fromWholesale: fromWholesale,
          notes: notes);
    }
    try {
      final res = await _dio!.post('/pos/wholesale/transfers/', data: {
        'itemName': itemName,
        'requestedQty': requestedQty,
        'unit': unit,
        'fromWholesale': fromWholesale,
        'notes': notes,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create transfer');
    }
  }

  Future<Map<String, dynamic>> approveTransfer(int id, int approvedQty) async {
    if (_isLocal) {
      return LocalDb.instance.approveTransfer(id, approvedQty);
    }
    try {
      final res = await _dio!.post('/pos/wholesale/transfers/$id/approve/',
          data: {'approvedQty': approvedQty});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to approve transfer');
    }
  }

  Future<Map<String, dynamic>> rejectTransfer(int id) async {
    if (_isLocal) return LocalDb.instance.rejectTransfer(id);
    try {
      final res = await _dio!.post('/pos/wholesale/transfers/$id/reject/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to reject transfer');
    }
  }

  Future<Map<String, dynamic>> receiveTransfer(int id) async {
    if (_isLocal) return LocalDb.instance.receiveTransfer(id);
    try {
      final res = await _dio!.post('/pos/wholesale/transfers/$id/receive/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to receive transfer');
    }
  }

  // ── Wholesale Inventory ────────────────────────────────────────────────────
  Future<List<dynamic>> fetchWholesaleLowStock({String? search}) async {
    if (_isLocal) {
      final rows =
          await LocalDb.instance.getItems(search: search, store: 'wholesale');
      return rows
          .where((i) => (i['stock'] as int) <= (i['lowStockThreshold'] as int))
          .toList();
    }
    try {
      final params = <String, dynamic>{'store': 'wholesale', 'low_stock': 'true'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res =
          await _dio!.get('/inventory/items/', queryParameters: params);
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load low stock items');
    }
  }

  Future<List<dynamic>> fetchWholesaleExpiryAlert() async {
    if (_isLocal) {
      final rows = await LocalDb.instance.getItems(store: 'wholesale');
      final soon = DateTime.now().add(const Duration(days: 90));
      return rows.where((i) {
        final exp = i['expiryDate'] as String?;
        if (exp == null) return false;
        final dt = DateTime.tryParse(exp);
        return dt != null && dt.isBefore(soon);
      }).toList();
    }
    try {
      final res = await _dio!.get('/inventory/items/',
          queryParameters: {'store': 'wholesale', 'expiry_soon': 'true'});
      final data = res.data;
      return data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load expiry alerts');
    }
  }

  Future<Map<String, dynamic>> fetchWholesaleInventoryValue() async {
    if (_isLocal) return LocalDb.instance.getWholesaleInventoryValue();
    try {
      final res = await _dio!.get('/wholesale/inventory-value/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load inventory value');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

final posApiProvider = Provider<PosApiClient>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return PosApiClient.local();
  return PosApiClient.remote(ref.watch(dioProvider));
});

bool isOfflineResult(Map<String, dynamic>? result) =>
    result != null && result['offline'] == true;

// ── Checkout notifier ──────────────────────────────────────────────────────────

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

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, AsyncValue<void>>(
        (ref) => CheckoutNotifier(ref));
