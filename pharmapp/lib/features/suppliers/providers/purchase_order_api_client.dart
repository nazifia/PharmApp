import 'package:dio/dio.dart';
import '../../../shared/models/purchase_order.dart';

class PurchaseOrderApiClient {
  final Dio _dio;

  PurchaseOrderApiClient(this._dio);

  Future<List<PurchaseOrder>> fetchOrders({int? supplierId}) async {
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
      return list
          .map((e) =>
              PurchaseOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load purchase orders');
    }
  }

  Future<PurchaseOrder> createOrder(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/purchase-orders/', data: data);
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create purchase order');
    }
  }

  Future<PurchaseOrder> fetchOrder(int id) async {
    try {
      final res = await _dio.get('/purchase-orders/$id/');
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load purchase order');
    }
  }

  Future<PurchaseOrder> updateOrder(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('/purchase-orders/$id/', data: data);
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to update purchase order');
    }
  }

  Future<PurchaseOrder> submitOrder(int id) async {
    try {
      final res = await _dio.post('/purchase-orders/$id/submit/');
      return PurchaseOrder.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
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
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to receive purchase order');
    }
  }
}
