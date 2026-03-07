import 'package:dio/dio.dart';
import '../../../shared/models/customer.dart';

// ── Wallet transaction ────────────────────────────────────────────────────────

class WalletTransaction {
  final int id;
  final String type;   // e.g. 'top_up' | 'payment' | 'refund'
  final double amount; // positive = credit, negative = debit
  final String note;
  final String date;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        id:     (j['id']     as num?)?.toInt()    ?? 0,
        type:   (j['type']   as String?)          ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        note:   (j['note']   as String?)          ?? '',
        date:   (j['date']   as String?)          ?? '',
      );

  String get displayType {
    switch (type.toLowerCase()) {
      case 'top_up':
      case 'topup':
        return 'Top-up';
      case 'payment':
        return 'Payment';
      case 'refund':
        return 'Refund';
      default:
        return type;
    }
  }
}

// ── Customer sale (recent purchase history) ───────────────────────────────────

class CustomerSale {
  final String date;
  final int items;
  final double total;
  final String status;

  CustomerSale({
    required this.date,
    required this.items,
    required this.total,
    required this.status,
  });

  factory CustomerSale.fromJson(Map<String, dynamic> j) => CustomerSale(
        date:   (j['date']   as String?) ?? '',
        items:  (j['items']  as num?)?.toInt()    ?? 0,
        total:  (j['total']  as num?)?.toDouble() ?? 0.0,
        status: (j['status'] as String?)          ?? 'Paid',
      );
}

// ── API client ────────────────────────────────────────────────────────────────

class CustomerApiClient {
  final Dio _dio;
  CustomerApiClient(this._dio);

  Future<List<Customer>> fetchCustomers() async {
    try {
      final res = await _dio.get('/customers/');
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customers');
    }
  }

  Future<Customer> fetchCustomer(int id) async {
    try {
      final res = await _dio.get('/customers/$id/');
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Customer not found');
    }
  }

  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/customers/', data: data);
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create customer');
    }
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('/customers/$id/', data: data);
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update customer');
    }
  }

  // ── Wallet ──────────────────────────────────────────────────────────────────

  Future<List<WalletTransaction>> fetchWalletTransactions(int id) async {
    try {
      final res = await _dio.get('/customers/$id/wallet/transactions/');
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list
          .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load wallet transactions');
    }
  }

  Future<Customer> topUpWallet(int id, double amount) async {
    try {
      final res = await _dio.post(
          '/customers/$id/wallet/topup/', data: {'amount': amount});
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to top up wallet');
    }
  }

  Future<Customer> deductWallet(int id, double amount) async {
    try {
      final res = await _dio.post(
          '/customers/$id/wallet/deduct/', data: {'amount': amount});
      return Customer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to deduct from wallet');
    }
  }

  // ── Sales history ───────────────────────────────────────────────────────────

  Future<List<CustomerSale>> fetchCustomerSales(int id) async {
    try {
      final res = await _dio.get('/customers/$id/sales/');
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list
          .map((e) => CustomerSale.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load customer sales');
    }
  }
}
