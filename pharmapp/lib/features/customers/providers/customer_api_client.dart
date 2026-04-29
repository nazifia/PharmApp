import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db.dart';
import '../../../shared/models/customer.dart';

const _kCustomersCachePrefix = 'cache_customers';

// ── Wallet transaction ─────────────────────────────────────────────────────────

class WalletTransaction {
  final int id;
  final String type;
  final double amount;
  final String note;
  final String date;
  final double? balanceAfter;

  WalletTransaction({required this.id, required this.type, required this.amount,
      required this.note, required this.date, this.balanceAfter});

  factory WalletTransaction.fromJson(Map<String, dynamic> j) {
    final rawDate = (j['date'] ?? j['createdAt'] as String?) ?? '';
    String formatted = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        formatted = '${dt.day.toString().padLeft(2,'0')}/'
            '${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
            '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2,'0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
      } catch (_) {}
    }
    return WalletTransaction(
      id: (j['id'] as num?)?.toInt() ?? 0,
      type: (j['type'] as String?) ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      note: (j['note'] as String?) ?? '',
      date: formatted,
      balanceAfter: ((j['balanceAfter'] ?? j['balance_after']) as num?)?.toDouble(),
    );
  }

  bool get isCredit {
    final t = type.toLowerCase();
    return t == 'topup' || t == 'top_up' || t == 'refund';
  }

  String get displayType {
    switch (type.toLowerCase()) {
      case 'top_up': case 'topup': return 'Top-up';
      case 'refund': return 'Refund';
      case 'payment': return 'Sale Payment';
      case 'deduction': return 'Deduction';
      case 'reset': return 'Wallet Reset';
      default: return type;
    }
  }
}

// ── Sale item detail ──────────────────────────────────────────────────────────

class SaleItemDetail {
  final String name;
  final String brand;
  final String unit;
  final int quantity;
  final double price;
  final double subtotal;
  final bool returned;

  SaleItemDetail({
    required this.name,
    required this.brand,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.subtotal,
    required this.returned,
  });

  factory SaleItemDetail.fromJson(Map<String, dynamic> j) => SaleItemDetail(
        name: (j['name'] as String?) ?? '',
        brand: (j['brand'] as String?) ?? '',
        unit: (j['unit'] as String?) ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0.0,
        returned: (j['returned'] as bool?) ?? false,
      );
}

// ── Customer sale ─────────────────────────────────────────────────────────────

class CustomerSale {
  final String date;
  final int itemCount;
  final double total;
  final String status;
  final String? receiptId;
  final String? paymentMethod;
  final String? dispenserName;
  final List<SaleItemDetail> itemDetails;

  CustomerSale({
    required this.date,
    required this.itemCount,
    required this.total,
    required this.status,
    this.receiptId,
    this.paymentMethod,
    this.dispenserName,
    this.itemDetails = const [],
  });

  // keep backward-compat getter
  int get items => itemCount;

  factory CustomerSale.fromJson(Map<String, dynamic> j) {
    final rawDate = (j['created'] as String?) ?? (j['date'] as String?) ?? '';
    String formatted = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        formatted = '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
            '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
      } catch (_) {}
    }

    final rawItems = j['items'];
    final List<SaleItemDetail> details = rawItems is List
        ? rawItems.map((e) => SaleItemDetail.fromJson(e as Map<String, dynamic>)).toList()
        : [];

    return CustomerSale(
      date: formatted,
      itemCount: details.isNotEmpty
          ? details.length
          : (rawItems is List ? rawItems.length : (rawItems as num?)?.toInt() ?? 0),
      total: (j['totalAmount'] as num?)?.toDouble() ??
          (j['total'] as num?)?.toDouble() ?? 0.0,
      status: (j['status'] as String?) ?? 'Paid',
      receiptId: j['receiptId'] as String?,
      paymentMethod: j['paymentMethod'] as String?,
      dispenserName: (j['dispenserName'] as String?)?.isNotEmpty == true
          ? j['dispenserName'] as String
          : null,
      itemDetails: details,
    );
  }
}

// ── API client ────────────────────────────────────────────────────────────────

class CustomerApiClient {
  final Dio? _dio;

  CustomerApiClient.local() : _dio = null;
  CustomerApiClient.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  Future<List<Customer>> fetchCustomers({int? branchId}) async {
    if (_isLocal) {
      return (await LocalDb.instance.getCustomers())
          .map((r) => Customer.fromJson(r)).toList();
    }
    // Branch-aware cache key — null branchId = org-wide (All Branches).
    final branchSegment = (branchId != null && branchId > 0) ? '_b$branchId' : '';
    final cacheKey = '$_kCustomersCachePrefix$branchSegment';

    try {
      final params = <String, dynamic>{};
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/customers/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List : data as List;
      final customers = list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();

      // Persist for offline access.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(list));
      // Also write to SQLite for more reliable offline fallback.
      if (!kIsWeb) {
        try {
          await LocalDb.instance.upsertCustomers(
              list.cast<Map<String, dynamic>>());
        } catch (_) {}
      }

      return customers;
    } on DioException catch (e) {
      // Connection-level failure — serve from cache if available.
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        }
        // SP cache empty — fall back to SQLite.
        if (!kIsWeb) {
          try {
            final rows = await LocalDb.instance.getCustomers();
            if (rows.isNotEmpty) {
              return rows.map((r) => Customer.fromJson(r)).toList();
            }
          } catch (_) {}
        }
        throw Exception('You are offline and no cached customer data is available yet.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customers');
    }
  }

  Future<Customer> fetchCustomer(int id) async {
    if (_isLocal) {
      final row = await LocalDb.instance.getCustomerById(id);
      if (row == null) throw Exception('Customer not found');
      return Customer.fromJson(row);
    }
    const prefix = 'cache_customer_';
    try {
      final res = await _dio!.get('/customers/$id/');
      final data = res.data as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$prefix$id', jsonEncode(data));
      return Customer.fromJson(data);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$prefix$id');
        if (raw != null) return Customer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        throw Exception('You are offline and this customer is not cached yet.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Customer not found');
    }
  }

  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    if (_isLocal) return Customer.fromJson(await LocalDb.instance.createCustomer(data));
    try {
      final res = await _dio!.post('/customers/', data: data);
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create customer');
    }
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async {
    if (_isLocal) return Customer.fromJson(await LocalDb.instance.updateCustomer(id, data));
    try {
      final res = await _dio!.patch('/customers/$id/', data: data);
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update customer');
    }
  }

  Future<void> deleteCustomer(int id) async {
    if (_isLocal) return LocalDb.instance.deleteCustomer(id);
    try {
      await _dio!.delete('/customers/$id/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete customer');
    }
  }

  // ── Wallet ─────────────────────────────────────────────────────────────────

  Future<List<WalletTransaction>> fetchWalletTransactions(int id) async {
    if (_isLocal) {
      return (await LocalDb.instance.getWalletTransactions(id))
          .map((r) => WalletTransaction.fromJson(r)).toList();
    }
    final cacheKey = 'cache_wallet_txns_$id';
    try {
      final res = await _dio!.get('/customers/$id/wallet/transactions/');
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List : data as List;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(list));
      return list.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          return list.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
        }
        throw Exception('You are offline and wallet history is not cached yet.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load wallet transactions');
    }
  }

  Future<void> topUpWallet(int id, double amount) async {
    if (_isLocal) return LocalDb.instance.topUpWallet(id, amount);
    try {
      await _dio!.post('/customers/$id/wallet/topup/', data: {'amount': amount});
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to top up wallet');
    }
  }

  Future<void> deductWallet(int id, double amount) async {
    if (_isLocal) return LocalDb.instance.deductWallet(id, amount);
    try {
      await _dio!.post('/customers/$id/wallet/deduct/', data: {'amount': amount});
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to deduct from wallet');
    }
  }

  Future<void> resetWallet(int id) async {
    if (_isLocal) return LocalDb.instance.resetWallet(id);
    try {
      await _dio!.post('/customers/$id/wallet/reset/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to reset wallet');
    }
  }

  Future<void> recordPayment(int id, {required double amount, String method = 'cash'}) async {
    if (_isLocal) return LocalDb.instance.recordPayment(id, amount, method);
    try {
      await _dio!.post('/customers/$id/record-payment/', data: {'amount': amount, 'method': method});
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to record payment');
    }
  }

  // ── Sales history ──────────────────────────────────────────────────────────

  Future<List<CustomerSale>> fetchCustomerSales(int id) async {
    if (_isLocal) {
      return (await LocalDb.instance.getCustomerSales(id))
          .map((r) => CustomerSale.fromJson(r)).toList();
    }
    final cacheKey = 'cache_customer_sales_$id';
    try {
      final res = await _dio!.get('/customers/$id/sales/');
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List : data as List;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(list));
      return list.map((e) => CustomerSale.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          return list.map((e) => CustomerSale.fromJson(e as Map<String, dynamic>)).toList();
        }
        throw Exception('You are offline and customer sales are not cached yet.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customer sales');
    }
  }
}
