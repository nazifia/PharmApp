import 'package:dio/dio.dart';
import '../../../shared/models/customer.dart';

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
}
