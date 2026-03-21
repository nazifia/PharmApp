import 'package:dio/dio.dart';
import '../../../shared/models/item.dart';

class InventoryApiClient {
  final Dio _dio;
  InventoryApiClient(this._dio);

  // DRF returns snake_case; Item.fromJson expects camelCase (per generated .g.dart).
  // This normalizer handles both so the app works with either backend convention.
  Map<String, dynamic> _normalize(Map<String, dynamic> j) => {
        'id':               j['id'],
        'name':             j['name'],
        'brand':            j['brand'],
        'dosageForm':       j['dosage_form']        ?? j['dosageForm'],
        'price':            j['price'],
        'costPrice':        j['cost']               ?? j['costPrice'] ?? 0,
        'stock':            j['stock'],
        'lowStockThreshold': j['low_stock_threshold'] ?? j['lowStockThreshold'],
        'barcode':          j['barcode'],
        'expiryDate':       j['expiry_date']        ?? j['expiryDate'],
      };

  Future<List<Item>> fetchInventory({String? search, String? store}) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (store != null && store.isNotEmpty) params['store'] = store;
      final res = await _dio.get('/inventory/items/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list.map((e) => Item.fromJson(_normalize(e as Map<String, dynamic>))).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load inventory');
    }
  }

  Future<Item> fetchById(int id) async {
    try {
      final res = await _dio.get('/inventory/items/$id/');
      return Item.fromJson(_normalize(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Item not found');
    }
  }

  Future<Item?> fetchItemByBarcode(String barcode) async {
    try {
      final res = await _dio.get('/inventory/items/', queryParameters: {'barcode': barcode});
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (list.isEmpty) return null;
      return Item.fromJson(_normalize(list[0] as Map<String, dynamic>));
    } catch (_) {
      return null;
    }
  }

  Future<Item> createItem(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/inventory/items/', data: data);
      return Item.fromJson(_normalize(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create item');
    }
  }

  Future<Item> updateItem(int itemId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('/inventory/items/$itemId/', data: data);
      return Item.fromJson(_normalize(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update item');
    }
  }

  Future<void> deleteItem(int itemId) async {
    try {
      await _dio.delete('/inventory/items/$itemId/');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete item');
    }
  }

  Future<Item> adjustStock(int itemId, int adjustment, String reason) async {
    try {
      final res = await _dio.post('/inventory/items/$itemId/adjust-stock/', data: {
        'adjustment': adjustment,
        'reason': reason,
      });
      return Item.fromJson(_normalize(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to adjust stock');
    }
  }
}
