import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/purchase_order.dart';

const _kPoCachePrefix = 'cache_purchase_orders';

class PurchaseOrderApiClient {
  final Dio _dio;

  PurchaseOrderApiClient(this._dio);

  Future<List<PurchaseOrder>> fetchOrders({int? supplierId}) async {
    final cacheKey =
        '$_kPoCachePrefix${supplierId != null ? '_s$supplierId' : ''}';
    try {
      final params = <String, dynamic>{};
      if (supplierId != null) params['supplier_id'] = supplierId;
      final res = await _dio.get(
        '/purchase-orders/',
        queryParameters: params.isNotEmpty ? params : null,
      );
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(list));
      return list
          .map((e) =>
              PurchaseOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          return (jsonDecode(raw) as List)
              .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw Exception(
            'You are offline and no cached purchase orders are available.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load purchase orders');
    }
  }

  Future<PurchaseOrder> createOrder(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/purchase-orders/', data: data);
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'Creating a purchase order requires an internet connection.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create purchase order');
    }
  }

  Future<PurchaseOrder> fetchOrder(int id) async {
    final cacheKey = '${_kPoCachePrefix}_$id';
    try {
      final res = await _dio.get('/purchase-orders/$id/');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(res.data));
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          return PurchaseOrder.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        throw Exception('You are offline and this purchase order is not cached.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load purchase order');
    }
  }

  Future<PurchaseOrder> updateOrder(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('/purchase-orders/$id/', data: data);
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'Updating a purchase order requires an internet connection.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to update purchase order');
    }
  }

  Future<PurchaseOrder> submitOrder(int id) async {
    try {
      final res = await _dio.post('/purchase-orders/$id/submit/');
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'Submitting a purchase order requires an internet connection.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to submit purchase order');
    }
  }

  Future<PurchaseOrder> receiveOrder(
      int id, List<Map<String, dynamic>> receivedItems) async {
    try {
      final res = await _dio.post(
        '/purchase-orders/$id/receive/',
        data: {'items': receivedItems},
      );
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'Receiving a purchase order requires an internet connection.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to receive purchase order');
    }
  }
}
