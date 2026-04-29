import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/local_db.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/branches/providers/branch_provider.dart';
import '../../../shared/models/sale.dart';

const _kSalesCacheKey           = 'cache_sales_list';
const _kPaymentRequestsCacheKey = 'cache_payment_requests';

// ═══════════════════════════════════════════════════════════════════════════════
//  POS API CLIENT — dev (local SQLite) + prod (Django REST)
// ═══════════════════════════════════════════════════════════════════════════════

class PosApiClient {
  final Dio? _dio;

  PosApiClient.local() : _dio = null;
  PosApiClient.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  // ── Cache helpers ──────────────────────────────────────────────────────────
  Future<void> _cacheStr(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<dynamic> _getCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw != null ? jsonDecode(raw) : null;
  }

  // ── Sales ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> submitCheckout(
    CheckoutPayload payload, {
    int? branchId,
  }) async {
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
        'patientName': payload.patientName,
        if (branchId != null && branchId > 0) 'branch_id': branchId,
      });
    }
    try {
      final body = {
        ...payload.toJson(),
        if (branchId != null && branchId > 0) 'branch_id': branchId,
      };
      final res = await _dio!.post('/pos/checkout/', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // No response means a connection-level failure (no internet, timeout, etc.).
      // Re-throw the original DioException so CheckoutNotifier can detect offline
      // and enqueue the sale instead of showing a generic error.
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Checkout failed');
    }
  }

  Future<List<dynamic>> fetchSales(
      {String? from, String? to, int? customerId, String? search, int? branchId}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getSales(from: from, to: to, customerId: customerId, search: search);
    }
    // Only cache unfiltered list requests (for the sales history screen default view).
    final isCacheable = from == null && to == null && customerId == null && (search == null || search.isEmpty);
    final cacheKey = branchId != null && branchId > 0
        ? '${_kSalesCacheKey}_b$branchId'
        : _kSalesCacheKey;
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (customerId != null) params['customer_id'] = customerId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/pos/sales/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(list));
      }
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) return jsonDecode(raw) as List;
        throw Exception('Offline — no cached sales history available');
      }
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
      final data = res.data as Map<String, dynamic>;
      await _cacheStr('cache_sale_$id', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_sale_$id');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — sale detail not cached');
      }
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
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Return failed');
    }
  }

  // ── Payment Requests ───────────────────────────────────────────────────────
  Future<List<dynamic>> fetchPaymentRequests({String? status, int? branchId}) async {
    if (_isLocal) return LocalDb.instance.getPaymentRequests(status: status);
    // Only cache the unfiltered list so the screen can load offline.
    final isCacheable = status == null;
    final prKey = branchId != null && branchId > 0
        ? '${_kPaymentRequestsCacheKey}_b$branchId'
        : _kPaymentRequestsCacheKey;
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/pos/payment-requests/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prKey, jsonEncode(list));
      }
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(prKey);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          if (status == null) return list;
          return list.where((r) => r['status'] == status).toList();
        }
        throw Exception('Offline — no cached payment requests available');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load payment requests');
    }
  }

  Future<Map<String, dynamic>> sendToCashier(
      List<Map<String, dynamic>> items,
      {int? customerId,
      int? cashierId,
      String paymentType = 'retail',
      String? patientName,
      int? branchId}) async {
    if (_isLocal) {
      return LocalDb.instance.createPaymentRequest(items,
          customerId: customerId,
          cashierId: cashierId,
          paymentType: paymentType,
          patientName: patientName);
    }
    try {
      final res = await _dio!.post('/pos/payment-requests/', data: {
        'items': items,
        if (customerId != null) 'customer_id': customerId,
        if (cashierId != null) 'cashier_id': cashierId,
        'payment_type': paymentType,
        if (patientName != null && patientName.isNotEmpty)
          'patientName': patientName,
        if (branchId != null && branchId > 0) 'branch_id': branchId,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow; // connection failure — let caller queue
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
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to complete payment request');
    }
  }

  // ── Dispensing Log ─────────────────────────────────────────────────────────
  static const _kLocalDispLogKey = 'local_dispensing_log';

  /// Fetches ALL pages from a DRF paginated endpoint and returns the combined list.
  Future<List<Map<String, dynamic>>> _fetchAllPages(
      String path, Map<String, dynamic>? params) async {
    final dio = _dio!;
    final all = <Map<String, dynamic>>[];
    String? url = path;
    Map<String, dynamic>? qp = params;
    while (url != null) {
      final res = await dio.get(url, queryParameters: qp);
      final data = res.data;
      if (data is Map && data.containsKey('results')) {
        all.addAll((data['results'] as List).cast<Map<String, dynamic>>());
        final next = data['next'] as String?;
        if (next != null && next.isNotEmpty) {
          final uri = Uri.parse(next);
          url = uri.path;
          qp  = Map<String, dynamic>.from(uri.queryParameters);
        } else {
          url = null;
        }
      } else {
        all.addAll((data as List).cast<Map<String, dynamic>>());
        url = null;
      }
    }
    return all;
  }

  List<Map<String, dynamic>> _filterEntries(
    List<Map<String, dynamic>> entries, {
    String? search,
    String? from,
    String? to,
  }) {
    var result = entries;
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((e) {
        final name  = (e['name']  as String? ?? '').toLowerCase();
        final brand = (e['brand'] as String? ?? '').toLowerCase();
        return name.contains(q) || brand.contains(q);
      }).toList();
    }
    if (from != null) {
      final fromDt = DateTime.tryParse(from);
      if (fromDt != null) {
        result = result.where((e) {
          final dt = DateTime.tryParse(e['createdAt'] as String? ?? '')?.toLocal();
          return dt == null || !dt.isBefore(fromDt);
        }).toList();
      }
    }
    if (to != null) {
      final toDt = DateTime.tryParse(to);
      if (toDt != null) {
        result = result.where((e) {
          final dt = DateTime.tryParse(e['createdAt'] as String? ?? '')?.toLocal();
          return dt == null || dt.isBefore(toDt);
        }).toList();
      }
    }
    return result;
  }

  Future<List<dynamic>> _getLocalDispensingEntries({
    String? search, String? from, String? to,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalDispLogKey);
    if (raw == null) return [];
    final all = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return _filterEntries(all, search: search, from: from, to: to);
  }

  /// Fetches sales from /pos/sales/ and expands each sale into per-item
  /// dispensing entries by resolving sale details (cache-first, then live fetch
  /// in parallel batches of 5). Local dispensing entries (from this device's
  /// checkouts) are merged in for any sale IDs not in the API response.
  Future<List<dynamic>> _fetchDispensingFromSales({
    String? search, String? from, String? to, int? branchId,
  }) async {
    final dio = _dio;
    if (dio == null) return _getLocalDispensingEntries(search: search, from: from, to: to);

    // 1. Fetch sales list
    final salesParams = <String, dynamic>{};
    if (from   != null) salesParams['from']      = from;
    if (to     != null) salesParams['to']        = to;
    if (search != null && search.isNotEmpty) salesParams['search'] = search;
    if (branchId != null && branchId > 0)   salesParams['branch_id'] = branchId;

    final salesList = await _fetchAllPages(
        '/pos/sales/', salesParams.isNotEmpty ? salesParams : null);

    // 2. Build a map: saleId → local item entries (from this device's checkouts)
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString(_kLocalDispLogKey);
    final localAll = localRaw != null
        ? (jsonDecode(localRaw) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    final localBySaleId = <dynamic, List<Map<String, dynamic>>>{};
    for (final e in localAll) {
      final sid = e['_localSaleId'];
      if (sid != null) (localBySaleId[sid] ??= []).add(e);
    }

    // 3. Resolve details for each sale (cache → live, batched)
    final apiSaleIds = <dynamic>{};
    final entries    = <Map<String, dynamic>>[];

    Future<Map<String, dynamic>?> resolveDetail(Map<String, dynamic> sale) async {
      final id = sale['id'];
      if (id == null) return null;
      final cached = await _getCache('cache_sale_$id');
      if (cached != null) return cached as Map<String, dynamic>;
      try {
        final res = await dio.get('/pos/sales/$id/');
        final data = res.data as Map<String, dynamic>;
        await _cacheStr('cache_sale_$id', data);
        return data;
      } catch (_) {
        return sale; // use list-level summary as last resort
      }
    }

    const batchSize = 5;
    for (int i = 0; i < salesList.length; i += batchSize) {
      final batch  = salesList.skip(i).take(batchSize).toList();
      final details = await Future.wait(batch.map(resolveDetail));

      for (int j = 0; j < batch.length; j++) {
        final sale   = batch[j];
        final detail = details[j];
        final id     = sale['id'];
        apiSaleIds.add(id);

        final createdAt = (detail?['createdAt'] as String?) ??
            (detail?['created_at'] as String?) ?? '';
        final dispenser  = (detail?['cashierName'] as String?) ??
            (detail?['cashier_name'] as String?) ?? '';
        final saleStatus = ((detail?['status'] as String?) ?? 'dispensed').toLowerCase();

        // Prefer local item-level entries for this device's sale
        if (localBySaleId.containsKey(id)) {
          entries.addAll(localBySaleId[id]!);
          continue;
        }

        final items = detail?['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) {
          // No item data available — show sale-level entry
          entries.add({
            'name':      'Sale #${sale['receiptId'] ?? sale['receipt_id'] ?? id}',
            'brand':     sale['customerName'] as String? ?? sale['customer_name'] as String? ?? '',
            'quantity':  1,
            'amount':    (sale['totalAmount'] as num?)?.toDouble() ??
                         (sale['total_amount'] as num?)?.toDouble() ?? 0,
            'status':    saleStatus,
            'createdAt': createdAt,
            'dispenser': dispenser,
          });
        } else {
          for (final raw in items) {
            final m   = raw as Map<String, dynamic>;
            final qty = (m['quantity'] as num?)?.toDouble() ?? 1;
            final prc = (m['price']    as num?)?.toDouble() ?? 0;
            entries.add({
              'name':      m['name']      as String? ?? m['itemName']  as String? ?? '',
              'brand':     m['brand']     as String? ?? '',
              'quantity':  qty,
              'amount':    prc * qty,
              'status':    saleStatus,
              'createdAt': createdAt,
              'dispenser': dispenser,
            });
          }
        }
      }
    }

    // 4. Append local entries whose sale ID is NOT in the API response
    //    (offline / queued sales not yet synced)
    for (final e in localAll) {
      final sid = e['_localSaleId'];
      if (sid != null && !apiSaleIds.contains(sid)) entries.add(e);
    }
    // Also include entries with no sale ID (very old local entries)
    for (final e in localAll) {
      if (e['_localSaleId'] == null) entries.add(e);
    }

    // 5. Apply search/date filter (sales endpoint already filtered by date/search,
    //    but local extras need filtering too)
    final filtered = _filterEntries(entries, search: search, from: from, to: to);

    // 6. Sort newest first
    filtered.sort((a, b) {
      final aDate = a['createdAt'] as String? ?? '';
      final bDate = b['createdAt'] as String? ?? '';
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Future<List<dynamic>> fetchDispensingLog(
      {String? search, String? from, String? to, int? branchId, int? userId}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getDispensingLog(search: search, from: from, to: to);
    }
    final isCacheable = (search == null || search.isEmpty) && from == null && to == null;
    final bSeg = (branchId != null && branchId > 0) ? '_b$branchId' : '';
    final uSeg = (userId != null && userId > 0) ? '_u$userId' : '';
    final cacheKey = 'cache_dispensing_log$bSeg$uSeg';
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      if (userId != null && userId > 0) params['dispensed_by'] = userId;
      final list = await _fetchAllPages(
          '/pos/dispensing-log/', params.isNotEmpty ? params : null);
      if (isCacheable) await _cacheStr(cacheKey, list);
      // Proper dispensing-log endpoint has data — use it directly
      if (list.isNotEmpty) return list;
      // Backend endpoint empty — derive from sales
      return _fetchDispensingFromSales(
          search: search, from: from, to: to, branchId: branchId);
    } on DioException catch (e) {
      if (e.response == null) {
        if (isCacheable) {
          final cached = await _getCache(cacheKey);
          if (cached != null) return cached as List;
        }
        // Offline: serve local entries only
        return _getLocalDispensingEntries(search: search, from: from, to: to);
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load dispensing log');
    }
  }

  Future<Map<String, dynamic>> fetchDispensingStats({int? branchId, int? userId}) async {
    if (_isLocal) return LocalDb.instance.getDispensingStats();
    final bSeg = (branchId != null && branchId > 0) ? '_b$branchId' : '';
    final uSeg = (userId != null && userId > 0) ? '_u$userId' : '';
    final cacheKey = 'cache_dispensing_stats$bSeg$uSeg';
    try {
      final params = <String, dynamic>{};
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      if (userId != null && userId > 0) params['dispensed_by'] = userId;
      final res = await _dio!.get('/pos/dispensing-log/stats/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data as Map<String, dynamic>;
      await _cacheStr(cacheKey, data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache(cacheKey);
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — no cached dispensing stats available');
      }
      if (e.response?.statusCode == 404) {
        return {'daily': {}, 'monthly': {}};
      }
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
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cacheStr('cache_expense_categories', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_expense_categories');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached expense categories available');
      }
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
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create expense category');
    }
  }

  Future<Map<String, dynamic>> updateExpenseCategory(
      int id, String name) async {
    if (_isLocal) return LocalDb.instance.updateExpenseCategory(id, name);
    try {
      final res = await _dio!
          .patch('/pos/expense-categories/$id/', data: {'name': name});
      await _invalidateCategoriesCache();
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to update expense category');
    }
  }

  Future<void> deleteExpenseCategory(int id) async {
    if (_isLocal) return LocalDb.instance.deleteExpenseCategory(id);
    try {
      await _dio!.delete('/pos/expense-categories/$id/');
      await _invalidateCategoriesCache();
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete expense category');
    }
  }

  Future<void> _invalidateCategoriesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_expense_categories');
  }

  Future<List<dynamic>> fetchExpenses({String? from, String? to}) async {
    if (_isLocal) return LocalDb.instance.getExpenses(from: from, to: to);
    final isCacheable = from == null && to == null;
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await _dio!.get('/pos/expenses/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr('cache_expenses', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache('cache_expenses');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached expenses available');
      }
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
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create expense');
    }
  }

  Future<void> deleteExpense(int id) async {
    if (_isLocal) return LocalDb.instance.deleteExpense(id);
    try {
      await _dio!.delete('/pos/expenses/$id/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete expense');
    }
  }

  Future<Map<String, dynamic>> fetchMonthlyReport(
      {int? month, int? year}) async {
    if (_isLocal) {
      return LocalDb.instance.getMonthlyReport(month: month, year: year);
    }
    final isCacheable = month == null && year == null;
    try {
      final params = <String, dynamic>{};
      if (month != null) params['month'] = month;
      if (year != null) params['year'] = year;
      final res = await _dio!.get('/pos/monthly-report/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data as Map<String, dynamic>;
      if (isCacheable) await _cacheStr('cache_monthly_report', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache('cache_monthly_report');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — no cached monthly report available');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load monthly report');
    }
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchSuppliers({String? search, int? branchId}) async {
    if (_isLocal) return LocalDb.instance.getSuppliers(search: search);
    final isCacheable = search == null || search.isEmpty;
    final cacheKey = branchId != null && branchId > 0
        ? 'cache_suppliers_b$branchId'
        : 'cache_suppliers';
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/pos/suppliers/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr(cacheKey, list);
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache(cacheKey);
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached suppliers available');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load suppliers');
    }
  }

  Future<Map<String, dynamic>> createSupplier({
    required String name,
    String phone = '',
    String contactInfo = '',
    int? branchId,
  }) async {
    if (_isLocal) {
      return LocalDb.instance
          .createSupplier(name, phone: phone, contactInfo: contactInfo);
    }
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'contactInfo': contactInfo,
      };
      if (branchId != null && branchId > 0) body['branch_id'] = branchId;
      final res = await _dio!.post('/pos/suppliers/', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create supplier');
    }
  }

  Future<Map<String, dynamic>> updateSupplier(
    int id, {
    required String name,
    String phone = '',
    String contactInfo = '',
    int? branchId,
  }) async {
    if (_isLocal) {
      return LocalDb.instance
          .updateSupplier(id, name: name, phone: phone, contactInfo: contactInfo);
    }
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'contactInfo': contactInfo,
      };
      if (branchId != null && branchId > 0) body['branch_id'] = branchId;
      final res = await _dio!.put('/pos/suppliers/$id/', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to update supplier');
    }
  }

  Future<void> deleteSupplier(int id) async {
    if (_isLocal) return LocalDb.instance.deleteSupplier(id);
    try {
      await _dio!.delete('/pos/suppliers/$id/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete supplier');
    }
  }

  // ── Procurements ───────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchProcurements({String? search, int? branchId}) async {
    if (_isLocal) return LocalDb.instance.getProcurements(search: search);
    final isCacheable = search == null || search.isEmpty;
    final cacheKey = branchId != null && branchId > 0
        ? 'cache_procurements_b$branchId'
        : 'cache_procurements';
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/pos/procurements/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr(cacheKey, list);
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache(cacheKey);
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached procurements available');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load procurements');
    }
  }

  Future<Map<String, dynamic>> createProcurement({
    required int supplierId,
    required List<Map<String, dynamic>> items,
    String status = 'draft',
    String destination = 'retail',
    int? branchId,
  }) async {
    if (_isLocal) {
      return LocalDb.instance.createProcurement(
          supplierId: supplierId,
          items: items,
          status: status,
          destination: destination);
    }
    try {
      final body = <String, dynamic>{
        'supplierId': supplierId,
        'items': items,
        'status': status,
        'destination': destination,
      };
      if (branchId != null && branchId > 0) body['branch_id'] = branchId;
      final res = await _dio!.post('/pos/procurements/', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to complete procurement');
    }
  }

  // ── Stock Checks ───────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchStockChecks({String storeType = 'retail'}) async {
    if (_isLocal) return LocalDb.instance.getStockChecks();
    final cacheKey = 'cache_stock_checks_$storeType';
    try {
      final res = await _dio!.get('/pos/stock-checks/',
          queryParameters: {'store_type': storeType});
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cacheStr(cacheKey, list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache(cacheKey);
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached stock checks available');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load stock checks');
    }
  }

  Future<Map<String, dynamic>> createStockCheck({String storeType = 'retail'}) async {
    if (_isLocal) return LocalDb.instance.createStockCheck();
    try {
      final res = await _dio!.post('/pos/stock-checks/',
          data: {'store_type': storeType});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create stock check');
    }
  }

  Future<Map<String, dynamic>> fetchStockCheckDetail(int id) async {
    if (_isLocal) return LocalDb.instance.getStockCheckDetail(id);
    try {
      final res = await _dio!.get('/pos/stock-checks/$id/');
      final data = res.data as Map<String, dynamic>;
      await _cacheStr('cache_stock_check_$id', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_stock_check_$id');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — stock check detail not cached');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Stock check not found');
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
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to approve stock check');
    }
  }

  Future<void> deleteStockCheck(int id) async {
    if (_isLocal) return LocalDb.instance.deleteStockCheck(id);
    try {
      await _dio!.delete('/pos/stock-checks/$id/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete stock check');
    }
  }

  Future<Map<String, dynamic>> fetchStockCheckReport(
      {String storeType = 'retail'}) async {
    if (_isLocal) {
      return {'summary': <String, dynamic>{}, 'completedChecks': <dynamic>[]};
    }
    final cacheKey = 'cache_stock_check_report_$storeType';
    try {
      final res = await _dio!.get('/pos/stock-checks/report/',
          queryParameters: {'store_type': storeType});
      final data = res.data as Map<String, dynamic>;
      await _cacheStr(cacheKey, data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache(cacheKey);
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — no cached report available');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load stock check report');
    }
  }

  // ── Cashiers ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchCashiers() async {
    if (_isLocal) return LocalDb.instance.getAllUsers(role: 'Cashier');
    try {
      final res =
          await _dio!.get('/pos/users/', queryParameters: {'role': 'Cashier'});
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cacheStr('cache_cashiers', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_cashiers');
        if (cached != null) return cached as List;
        return []; // empty list is safe — no cashiers available offline
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load cashiers');
    }
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchNotifications() async {
    if (_isLocal) return LocalDb.instance.getNotifications();
    try {
      final res = await _dio!.get('/pos/notifications/');
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cacheStr('cache_notifications', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_notifications');
        if (cached != null) return cached as List;
        return []; // graceful empty rather than error
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load notifications');
    }
  }

  Future<int> fetchNotificationCount() async {
    if (_isLocal) return LocalDb.instance.getUnreadCount();
    try {
      final res = await _dio!.get('/pos/notifications/count/');
      final count = (res.data['count'] as num?)?.toInt() ?? 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cache_notification_count', count);
      return count;
    } on DioException catch (_) {
      // Return cached count on network failure
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('cache_notification_count') ?? 0;
    }
  }

  Future<void> markNotificationRead(int id) async {
    if (_isLocal) return LocalDb.instance.markNotificationRead(id);
    try {
      await _dio!.post('/pos/notifications/$id/read/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to mark notification read');
    }
  }

  Future<void> deleteNotification(int id) async {
    if (_isLocal) return; // local mode: no-op
    try {
      await _dio!.delete('/pos/notifications/$id/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to delete notification');
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_isLocal) return;
    try {
      await _dio!.post('/pos/notifications/read-all/');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to mark all notifications read');
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
  Future<List<dynamic>> fetchUsers({String? search, String? role, int? branchId}) async {
    if (_isLocal) {
      return LocalDb.instance.getAllUsers(search: search, role: role);
    }
    final isCacheable = (search == null || search.isEmpty) &&
        (role == null || role.isEmpty) &&
        (branchId == null || branchId == 0);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (role != null && role.isNotEmpty) params['role'] = role;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/pos/users/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr('cache_users', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_users');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached users available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load users');
    }
  }

  Future<Map<String, dynamic>> createUser({
    required String phoneNumber,
    required String password,
    String role = 'Cashier',
    String username = '',
    int? branchId,
  }) async {
    if (_isLocal) {
      return LocalDb.instance.createUser(phoneNumber, password, role, username: username);
    }
    try {
      final body = <String, dynamic>{
        'phoneNumber': phoneNumber,
        'password': password,
        'role': role,
      };
      if (branchId != null && branchId > 0) body['branch_id'] = branchId;
      final res = await _dio!.post('/pos/users/', data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create user');
    }
  }

  Future<void> deleteUser(int id) async {
    if (_isLocal) return LocalDb.instance.deleteUser(id);
    try {
      await _dio!.delete('/pos/users/$id/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete user');
    }
  }

  Future<void> changePassword(int id, String newPassword) async {
    if (_isLocal) {
      return LocalDb.instance.changeUserPassword(id, newPassword);
    }
    try {
      await _dio!.post('/pos/users/$id/change-password/',
          data: {'newPassword': newPassword});
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to change password');
    }
  }

  Future<Map<String, dynamic>> updateUser(int id,
      {String? role, bool? isActive, String? username, String? fullname, int? branchId}) async {
    if (_isLocal) {
      return LocalDb.instance.updateUser(id, role: role, isActive: isActive, username: username, fullname: fullname);
    }
    try {
      final data = <String, dynamic>{};
      if (role != null) data['role'] = role;
      if (isActive != null) data['is_active'] = isActive;
      if (username != null) data['username'] = username;
      if (fullname != null) data['fullname'] = fullname;
      if (branchId != null) data['branch_id'] = branchId > 0 ? branchId : null;
      final res = await _dio!.patch('/pos/users/$id/', data: data);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update user');
    }
  }

  /// Returns permission matrix from GET /auth/users/<id>/permissions/
  Future<Map<String, dynamic>> fetchUserPermissions(int userId) async {
    if (_isLocal) {
      return {'user_id': userId, 'role': '', 'rows': []};
    }
    try {
      final res = await _dio!.get('/auth/users/$userId/permissions/');
      final data = res.data as Map<String, dynamic>;
      await _cacheStr('cache_user_perms_$userId', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_user_perms_$userId');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — user permissions not cached');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load permissions');
    }
  }

  /// POST /auth/users/<id>/permissions/ with {overrides: {key: 'inherit'|'grant'|'revoke'}}
  Future<Map<String, dynamic>> saveUserPermissions(
      int userId, Map<String, String> overrides) async {
    if (_isLocal) {
      return {'user_id': userId, 'role': '', 'rows': []};
    }
    try {
      final res = await _dio!.post(
        '/auth/users/$userId/permissions/',
        data: {'overrides': overrides},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to save permissions');
    }
  }

  // ── Wholesale ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchWholesaleDashboard() async {
    if (_isLocal) return LocalDb.instance.getWholesaleDashboard();
    try {
      final res = await _dio!.get('/pos/wholesale/dashboard/');
      final data = res.data as Map<String, dynamic>;
      await _cacheStr('cache_wholesale_dashboard', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_wholesale_dashboard');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — wholesale dashboard not cached');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load wholesale dashboard');
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
    final isCacheable = search == null || search.isEmpty;
    try {
      final params = <String, dynamic>{'wholesale': 'true'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio!.get('/customers/', queryParameters: params);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr('cache_wholesale_customers', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_wholesale_customers');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached wholesale customers available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load wholesale customers');
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
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cacheStr('cache_wholesale_neg_customers', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_wholesale_neg_customers');
        if (cached != null) return cached as List;
        return []; // return empty list rather than error for negative-balance view
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customers');
    }
  }

  Future<List<dynamic>> fetchWholesaleSales(
      {String? from, String? to, String? search, int? branchId}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getSales(from: from, to: to, search: search, isWholesale: true);
    }
    final isCacheable = from == null && to == null && (search == null || search.isEmpty);
    final wsKey = branchId != null && branchId > 0
        ? 'cache_wholesale_sales_b$branchId'
        : 'cache_wholesale_sales';
    try {
      final params = <String, dynamic>{'wholesale': 'true'};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/pos/sales/', queryParameters: params);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr(wsKey, list);
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache(wsKey);
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached wholesale sales available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load wholesale sales');
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
      final data = res.data as Map<String, dynamic>;
      await _cacheStr('cache_wsale_$id', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_wsale_$id');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — wholesale sale detail not cached');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Sale not found');
    }
  }

  Future<Map<String, dynamic>> returnWholesaleItem(int saleId,
      {required int saleItemId,
      required double quantity,
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
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Return failed');
    }
  }

  Future<List<dynamic>> fetchWholesaleSalesByUser(
      {String? from, String? to}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getWholesaleSalesByUser(from: from, to: to);
    }
    final isCacheable = from == null && to == null;
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await _dio!.get('/pos/wholesale/sales/by-user/', queryParameters: params);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr('cache_wholesale_sales_user', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache('cache_wholesale_sales_user');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached sales by user available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load sales by user');
    }
  }

  // ── Transfers ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> fetchTransfers(
      {String? status, String? direction}) async {
    if (_isLocal) {
      return LocalDb.instance
          .getTransfers(status: status, direction: direction);
    }
    final isCacheable = status == null && direction == null;
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (direction != null) params['direction'] = direction;
      final res = await _dio!.get('/pos/wholesale/transfers/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr('cache_transfers', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        // For filtered queries, fall back to the full unfiltered cache
        final cached = await _getCache('cache_transfers');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached transfers available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load transfers');
    }
  }

  Future<Map<String, dynamic>> createTransfer({
    required String itemName,
    required double requestedQty,
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
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create transfer');
    }
  }

  Future<Map<String, dynamic>> approveTransfer(int id, double approvedQty) async {
    if (_isLocal) {
      return LocalDb.instance.approveTransfer(id, approvedQty);
    }
    try {
      final res = await _dio!.post('/pos/wholesale/transfers/$id/approve/',
          data: {'approvedQty': approvedQty});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
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
      if (e.response == null) rethrow;
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
    final isCacheable = search == null || search.isEmpty;
    try {
      final params = <String, dynamic>{'store': 'wholesale', 'low_stock': 'true'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res =
          await _dio!.get('/inventory/items/', queryParameters: params);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (isCacheable) await _cacheStr('cache_wholesale_low_stock', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null && isCacheable) {
        final cached = await _getCache('cache_wholesale_low_stock');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached low stock data available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load low stock items');
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
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cacheStr('cache_wholesale_expiry', list);
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_wholesale_expiry');
        if (cached != null) return cached as List;
        throw Exception('Offline — no cached expiry alerts available');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load expiry alerts');
    }
  }

  Future<Map<String, dynamic>> fetchWholesaleInventoryValue() async {
    if (_isLocal) return LocalDb.instance.getWholesaleInventoryValue();
    try {
      final res = await _dio!.get('/pos/wholesale/inventory-value/');
      final data = res.data as Map<String, dynamic>;
      await _cacheStr('cache_wholesale_inv_value', data);
      return data;
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache('cache_wholesale_inv_value');
        if (cached != null) return cached as Map<String, dynamic>;
        throw Exception('Offline — inventory value not cached');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load inventory value');
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

/// Watched by AppShell on startup to warm the payment-requests cache so that
/// the cashier's screen has data available when the device goes offline.
final paymentRequestsPreloadProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) {
  final branch   = ref.watch(activeBranchProvider);
  final branchId = (branch != null && branch.id > 0) ? branch.id : null;
  return ref.watch(posApiProvider).fetchPaymentRequests(branchId: branchId);
});

bool isOfflineResult(Map<String, dynamic>? result) =>
    result != null && result['offline'] == true;

// ── Checkout notifier ──────────────────────────────────────────────────────────

class CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> _saveLocalDispensingEntries(Map<String, dynamic> result) async {
    final items = result['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return;
    final createdAt = result['createdAt'] as String? ??
        result['created_at'] as String? ??
        DateTime.now().toIso8601String();
    final saleId = result['id'];
    final user = _ref.read(currentUserProvider);
    final dispenserName = user?.username ?? '';

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(PosApiClient._kLocalDispLogKey);
    final List<dynamic> entries =
        existing != null ? (jsonDecode(existing) as List) : [];

    for (final raw in items.reversed) {
      final m = raw as Map<String, dynamic>;
      final qty = (m['quantity'] as num?)?.toDouble() ?? 1;
      final price = (m['price'] as num?)?.toDouble() ?? 0;
      entries.insert(0, {
        'name': m['name'] ?? m['itemName'] ?? '',
        'brand': m['brand'] ?? '',
        'quantity': qty,
        'amount': price * qty,
        'status': 'dispensed',
        'createdAt': createdAt,
        'dispenser': dispenserName,
        '_localSaleId': saleId,
      });
    }
    final trimmed = entries.take(500).toList();
    await prefs.setString(PosApiClient._kLocalDispLogKey, jsonEncode(trimmed));
  }

  Future<Map<String, dynamic>?> processCheckout(CheckoutPayload payload) async {
    state = const AsyncValue.loading();

    final branch = _ref.read(activeBranchProvider);
    int? branchId = (branch != null && branch.id > 0) ? branch.id : null;
    if (branchId == null) {
      final user = _ref.read(currentUserProvider);
      if (user != null && user.branchId > 0) {
        const adminRoles = {'Admin', 'Manager', 'Wholesale Manager'};
        if (!adminRoles.contains(user.role)) branchId = user.branchId;
      }
    }

    // Short-circuit: if device is already offline, enqueue without a network call.
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      await _ref.read(offlineQueueProvider.notifier).enqueue(payload);
      state = const AsyncValue.data(null);
      return {'offline': true};
    }

    try {
      final result = await _ref.read(posApiProvider).submitCheckout(
        payload,
        branchId: branchId,
      );
      await _saveLocalDispensingEntries(result);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      // Connection-level failure even though we thought we were online.
      // Queue the sale and return the offline marker so the UI shows the
      // "Queued for sync" sheet rather than a generic error.
      if (e.response == null) {
        await _ref.read(offlineQueueProvider.notifier).enqueue(payload);
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, AsyncValue<void>>(
        (ref) => CheckoutNotifier(ref));

// ═══════════════════════════════════════════════════════════════════════════════
//  OFFLINE-AWARE WRITE NOTIFIERS
// ═══════════════════════════════════════════════════════════════════════════════

// ── Returns (retail + wholesale) ─────────────────────────────────────────────

class PosReturnNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  PosReturnNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> returnItem(int saleId,
      {required int saleItemId,
      required int quantity,
      String refundMethod = 'wallet',
      String reason = ''}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.returnItem(saleId,
          saleItemId: saleItemId,
          quantity: quantity,
          refundMethod: refundMethod,
          reason: reason);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/sales/$saleId/return-item/',
          body: {'sale_item_id': saleItemId, 'quantity': quantity,
                 'refund_method': refundMethod, 'reason': reason},
          description: 'Return item from sale #$saleId',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final posReturnNotifierProvider =
    StateNotifierProvider<PosReturnNotifier, AsyncValue<void>>(
        (ref) => PosReturnNotifier(ref.watch(posApiProvider), ref));

// ── Payment Requests ──────────────────────────────────────────────────────────

class PaymentRequestNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  PaymentRequestNotifier(this._api, this._ref)
      : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> sendToCashier(
      List<Map<String, dynamic>> items,
      {int? customerId, int? cashierId,
       String paymentType = 'retail', String? patientName}) async {
    state = const AsyncValue.loading();
    final branch = _ref.read(activeBranchProvider);
    int? branchId = (branch != null && branch.id > 0) ? branch.id : null;
    if (branchId == null) {
      final user = _ref.read(currentUserProvider);
      if (user != null && user.branchId > 0) {
        const adminRoles = {'Admin', 'Manager', 'Wholesale Manager'};
        if (!adminRoles.contains(user.role)) branchId = user.branchId;
      }
    }
    try {
      final result = await _api.sendToCashier(items,
          customerId: customerId, cashierId: cashierId,
          paymentType: paymentType, patientName: patientName,
          branchId: branchId);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        final body = {
          'items': items,
          if (customerId != null) 'customer_id': customerId,
          if (cashierId != null) 'cashier_id': cashierId,
          'payment_type': paymentType,
          if (patientName != null && patientName.isNotEmpty) 'patientName': patientName,
          if (branchId != null) 'branch_id': branchId,
        };
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/payment-requests/',
          body: body,
          description: 'Send to cashier',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> acceptPaymentRequest(int id) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.acceptPaymentRequest(id);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/payment-requests/$id/accept/',
          description: 'Accept payment request #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> rejectPaymentRequest(int id) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.rejectPaymentRequest(id);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/payment-requests/$id/reject/',
          description: 'Reject payment request #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final paymentRequestNotifierProvider =
    StateNotifierProvider<PaymentRequestNotifier, AsyncValue<void>>(
        (ref) => PaymentRequestNotifier(ref.watch(posApiProvider), ref));

// ── Expenses ──────────────────────────────────────────────────────────────────

class ExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  ExpenseNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> createExpenseCategory(String name) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createExpenseCategory(name);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/expense-categories/',
          body: {'name': name},
          description: 'Create expense category "$name"',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateExpenseCategory(
      int id, String name) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.updateExpenseCategory(id, name);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'PATCH', '/pos/expense-categories/$id/',
          body: {'name': name},
          description: 'Update expense category "$name"',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteExpenseCategory(int id, String name) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteExpenseCategory(id);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/pos/expense-categories/$id/',
          description: 'Delete expense category "$name"',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteExpense(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteExpense(id);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/pos/expenses/$id/',
          description: 'Delete expense #$id',
        );
        // Remove from list cache immediately.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_expenses');
        if (raw != null) {
          final list = (jsonDecode(raw) as List)
              .where((e) => (e as Map<String, dynamic>)['id'] != id)
              .toList();
          await prefs.setString('cache_expenses', jsonEncode(list));
        }
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<Map<String, dynamic>?> createExpense({
    required int categoryId, required double amount,
    String description = '', String? date,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createExpense(
        categoryId: categoryId, amount: amount,
        description: description, date: date);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/expenses/',
          body: {'category_id': categoryId, 'amount': amount,
                 'description': description, if (date != null) 'date': date},
          description: 'Create expense ₦$amount',
        );
        // Patch the expense list cache so the new expense appears immediately.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_expenses');
        final list = raw != null
            ? List<dynamic>.from(jsonDecode(raw) as List)
            : <dynamic>[];
        final tempExpense = {
          'id': -DateTime.now().millisecondsSinceEpoch,
          'category_id': categoryId,
          'amount': amount,
          'description': description,
          'date': date ?? DateTime.now().toIso8601String().split('T').first,
          'status': 'pending_sync',
        };
        list.insert(0, tempExpense);
        await prefs.setString('cache_expenses', jsonEncode(list));
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<void>>(
        (ref) => ExpenseNotifier(ref.watch(posApiProvider), ref));

// ── Suppliers ─────────────────────────────────────────────────────────────────

class SupplierNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  SupplierNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> createSupplier({
    required String name, String phone = '', String contactInfo = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createSupplier(
          name: name, phone: phone, contactInfo: contactInfo);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/suppliers/',
          body: {'name': name, 'phone': phone, 'contactInfo': contactInfo},
          description: 'Create supplier "$name"',
        );
        // Patch the supplier list cache so new supplier appears immediately.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_suppliers');
        final list = raw != null
            ? List<dynamic>.from(jsonDecode(raw) as List)
            : <dynamic>[];
        list.insert(0, {
          'id': -DateTime.now().millisecondsSinceEpoch,
          'name': name,
          'phone': phone,
          'contactInfo': contactInfo,
          'status': 'pending_sync',
        });
        await prefs.setString('cache_suppliers', jsonEncode(list));
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateSupplier(
    int id, {
    required String name, String phone = '', String contactInfo = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.updateSupplier(
          id, name: name, phone: phone, contactInfo: contactInfo);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'PUT', '/pos/suppliers/$id/',
          body: {'name': name, 'phone': phone, 'contactInfo': contactInfo},
          description: 'Update supplier "$name"',
        );
        // Patch cache immediately.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_suppliers');
        if (raw != null) {
          final list = (jsonDecode(raw) as List).map((e) {
            final m = e as Map<String, dynamic>;
            if (m['id'] == id) {
              return {...m, 'name': name, 'phone': phone, 'contactInfo': contactInfo};
            }
            return m;
          }).toList();
          await prefs.setString('cache_suppliers', jsonEncode(list));
        }
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteSupplier(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteSupplier(id);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/pos/suppliers/$id/',
          description: 'Delete supplier #$id',
        );
        // Remove from supplier cache immediately.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_suppliers');
        if (raw != null) {
          final list = (jsonDecode(raw) as List)
              .where((e) => (e as Map<String, dynamic>)['id'] != id)
              .toList();
          await prefs.setString('cache_suppliers', jsonEncode(list));
        }
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final supplierNotifierProvider =
    StateNotifierProvider<SupplierNotifier, AsyncValue<void>>(
        (ref) => SupplierNotifier(ref.watch(posApiProvider), ref));

// ── Procurements ──────────────────────────────────────────────────────────────

class ProcurementNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  ProcurementNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> createProcurement({
    required int supplierId, required List<Map<String, dynamic>> items,
    String status = 'draft', String destination = 'retail',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createProcurement(
          supplierId: supplierId, items: items,
          status: status, destination: destination);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/procurements/',
          body: {'supplier_id': supplierId, 'items': items,
                 'status': status, 'destination': destination},
          description: 'Create procurement from supplier #$supplierId',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> completeProcurement(int id,
      {String destination = 'retail'}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.completeProcurement(id, destination: destination);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/procurements/$id/complete/',
          body: {'destination': destination},
          description: 'Complete procurement #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final procurementNotifierProvider =
    StateNotifierProvider<ProcurementNotifier, AsyncValue<void>>(
        (ref) => ProcurementNotifier(ref.watch(posApiProvider), ref));

// ── Stock Checks ──────────────────────────────────────────────────────────────

class StockCheckNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  StockCheckNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> createStockCheck() async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createStockCheck();
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/stock-checks/',
          description: 'Create stock check',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> addStockCheckItem(int checkId, int itemId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.addStockCheckItem(checkId, itemId);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/stock-checks/$checkId/items/',
          body: {'item_id': itemId},
          description: 'Add item to stock check #$checkId',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateStockCheckItem(
      int checkId, int itemId, int actualQuantity, String itemStatus) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.updateStockCheckItem(
          checkId, itemId, actualQuantity, itemStatus);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'PATCH', '/pos/stock-checks/$checkId/items/$itemId/',
          body: {'actual_quantity': actualQuantity, 'status': itemStatus},
          description: 'Update stock check item #$itemId',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> approveStockCheck(int id) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.approveStockCheck(id);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/stock-checks/$id/approve/',
          description: 'Approve stock check #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteStockCheck(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteStockCheck(id);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/pos/stock-checks/$id/',
          description: 'Delete stock check #$id',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final stockCheckNotifierProvider =
    StateNotifierProvider<StockCheckNotifier, AsyncValue<void>>(
        (ref) => StockCheckNotifier(ref.watch(posApiProvider), ref));

// ── Transfers ─────────────────────────────────────────────────────────────────

class TransferNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  TransferNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> createTransfer({
    required String itemName, required double requestedQty,
    String unit = 'Pcs', bool fromWholesale = true, String notes = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createTransfer(
          itemName: itemName, requestedQty: requestedQty,
          unit: unit, fromWholesale: fromWholesale, notes: notes);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/wholesale/transfers/',
          body: {'itemName': itemName, 'requestedQty': requestedQty,
                 'unit': unit, 'fromWholesale': fromWholesale, 'notes': notes},
          description: 'Create transfer "$itemName"',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> approveTransfer(int id, double approvedQty) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.approveTransfer(id, approvedQty);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/wholesale/transfers/$id/approve/',
          body: {'approvedQty': approvedQty},
          description: 'Approve transfer #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> rejectTransfer(int id) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.rejectTransfer(id);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/wholesale/transfers/$id/reject/',
          description: 'Reject transfer #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> receiveTransfer(int id) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.receiveTransfer(id);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/wholesale/transfers/$id/receive/',
          description: 'Receive transfer #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final transferNotifierProvider =
    StateNotifierProvider<TransferNotifier, AsyncValue<void>>(
        (ref) => TransferNotifier(ref.watch(posApiProvider), ref));

// ── User Management ───────────────────────────────────────────────────────────

class UserNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  UserNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, dynamic>?> createUser({
    required String phoneNumber, required String password,
    String role = 'Cashier', String username = '', int? branchId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.createUser(
          phoneNumber: phoneNumber, password: password,
          role: role, username: username, branchId: branchId);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        final body = <String, dynamic>{
          'phoneNumber': phoneNumber,
          'password': password,
          'role': role,
          if (username.isNotEmpty) 'username': username,
          if (branchId != null && branchId > 0) 'branch_id': branchId,
        };
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/users/',
          body: body,
          description: 'Create user "$phoneNumber"',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteUser(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteUser(id);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/pos/users/$id/',
          description: 'Delete user #$id',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> changePassword(int id, String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await _api.changePassword(id, newPassword);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/users/$id/change-password/',
          body: {'newPassword': newPassword},
          description: 'Change password for user #$id',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<Map<String, dynamic>?> updateUser(int id,
      {String? role, bool? isActive, String? username, String? fullname,
       int? branchId}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.updateUser(
          id, role: role, isActive: isActive, username: username,
          fullname: fullname, branchId: branchId);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        final body = <String, dynamic>{};
        if (role != null) body['role'] = role;
        if (isActive != null) body['is_active'] = isActive;
        if (username != null) body['username'] = username;
        if (fullname != null) body['fullname'] = fullname;
        if (branchId != null) body['branch_id'] = branchId > 0 ? branchId : null;
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'PATCH', '/pos/users/$id/',
          body: body,
          description: 'Update user #$id',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> saveUserPermissions(
      int userId, Map<String, String> overrides) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.saveUserPermissions(userId, overrides);
      state = const AsyncValue.data(null);
      return result;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/auth/users/$userId/permissions/',
          body: {'overrides': overrides},
          description: 'Save permissions for user #$userId',
        );
        state = const AsyncValue.data(null);
        return {'offline': true};
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final userNotifierProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<void>>(
        (ref) => UserNotifier(ref.watch(posApiProvider), ref));

// ── Notifications ─────────────────────────────────────────────────────────────

class NotificationActionNotifier extends StateNotifier<AsyncValue<void>> {
  final PosApiClient _api;
  final Ref _ref;
  NotificationActionNotifier(this._api, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> markRead(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.markNotificationRead(id);
      state = const AsyncValue.data(null);
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/notifications/$id/read/',
          description: 'Mark notification #$id read',
        );
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationActionNotifierProvider =
    StateNotifierProvider<NotificationActionNotifier, AsyncValue<void>>(
        (ref) => NotificationActionNotifier(ref.watch(posApiProvider), ref));

