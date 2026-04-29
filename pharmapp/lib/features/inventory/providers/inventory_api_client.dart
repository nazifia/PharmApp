import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db.dart';
import '../../../shared/models/item.dart';

const _kInventoryCachePrefix = 'cache_inventory';

class InventoryApiClient {
  final Dio? _dio;

  InventoryApiClient.local() : _dio = null;
  InventoryApiClient.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  Map<String, dynamic> _norm(Map<String, dynamic> j) => {
        'id': j['id'],
        'name': j['name'],
        'brand': j['brand'] ?? '',
        'dosageForm': j['dosage_form'] ?? j['dosageForm'] ?? '',
        'price': j['price'],
        'costPrice': j['cost_price'] ?? j['cost'] ?? j['costPrice'] ?? 0,
        'markup': j['markup'] ?? 0,
        'branchId': j['branch_id'] ?? j['branchId'] ?? 0,
        'stock': j['stock'],
        'lowStockThreshold': j['low_stock_threshold'] ?? j['lowStockThreshold'] ?? 10,
        'barcode': j['barcode'] ?? '',
        'expiryDate': j['expiry_date'] ?? j['expiryDate'],
        'store': j['store'] ?? '',
        'unitOfDispensing': j['unit_of_dispensing'] ?? j['unitOfDispensing'] ?? '',
      };

  Future<List<Item>> fetchInventory({String? search, String? store, int? branchId}) async {
    if (_isLocal) {
      return (await LocalDb.instance.getItems(search: search, store: store))
          .map(_toItem).toList();
    }
    // Branch-aware cache key — null branchId = org-wide (All Branches).
    final branchSegment = (branchId != null && branchId > 0) ? '_b$branchId' : '';
    final cacheKey = search == null
        ? '$_kInventoryCachePrefix$branchSegment${store != null ? "_$store" : ""}'
        : null;

    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (store != null && store.isNotEmpty) params['store'] = store;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio!.get('/inventory/items/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List : data as List;
      final items = list.map((e) => Item.fromJson(_norm(e as Map<String, dynamic>))).toList();

      // Persist successful result for offline access (non-search only).
      if (cacheKey != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(list));
        // Also write to SQLite for more reliable offline fallback.
        if (!kIsWeb) {
          try {
            await LocalDb.instance.upsertItems(
                list.cast<Map<String, dynamic>>());
          } catch (_) {}
        }
      }

      return items;
    } on DioException catch (e) {
      // Connection-level failure — serve from cache if available.
      if (e.response == null && cacheKey != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          return list.map((e) => Item.fromJson(_norm(e as Map<String, dynamic>))).toList();
        }
        // SP cache empty — fall back to SQLite.
        if (!kIsWeb) {
          try {
            final rows = await LocalDb.instance.getItems(store: store);
            if (rows.isNotEmpty) {
              return rows.map((r) => Item.fromJson(_norm(r))).toList();
            }
          } catch (_) {}
        }
        throw Exception('You are offline and no cached inventory is available yet.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load inventory');
    }
  }

  Future<Item> fetchById(int id) async {
    if (_isLocal) {
      final row = await LocalDb.instance.getItemById(id);
      if (row == null) throw Exception('Item not found');
      return _toItem(row);
    }
    const prefix = 'cache_inventory_item_';
    try {
      final res = await _dio!.get('/inventory/items/$id/');
      final normalized = _norm(res.data as Map<String, dynamic>);
      // Cache for offline access.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$prefix$id', jsonEncode(normalized));
      return Item.fromJson(normalized);
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$prefix$id');
        if (raw != null) {
          return Item.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        throw Exception('You are offline and this item is not cached yet.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Item not found');
    }
  }

  Future<Item?> fetchItemByBarcode(String barcode) async {
    if (_isLocal) {
      final row = await LocalDb.instance.getItemByBarcode(barcode);
      return row != null ? _toItem(row) : null;
    }
    try {
      final res = await _dio!.get('/inventory/items/', queryParameters: {'barcode': barcode});
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List : data as List;
      return list.isEmpty ? null : Item.fromJson(_norm(list[0] as Map<String, dynamic>));
    } catch (_) { return null; }
  }

  Future<Item> createItem(Map<String, dynamic> data) async {
    if (_isLocal) return _toItem(await LocalDb.instance.createItem(data));
    try {
      final res = await _dio!.post('/inventory/items/', data: data);
      return Item.fromJson(_norm(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response == null) rethrow; // connection failure — let caller queue
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create item');
    }
  }

  Future<Item> updateItem(int itemId, Map<String, dynamic> data) async {
    if (_isLocal) return _toItem(await LocalDb.instance.updateItem(itemId, data));
    try {
      final res = await _dio!.patch('/inventory/items/$itemId/', data: data);
      return Item.fromJson(_norm(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update item');
    }
  }

  Future<void> deleteItem(int itemId) async {
    if (_isLocal) return LocalDb.instance.deleteItem(itemId);
    try {
      await _dio!.delete('/inventory/items/$itemId/');
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete item');
    }
  }

  Future<Item> adjustStock(int itemId, int adjustment, String reason) async {
    if (_isLocal) return _toItem(await LocalDb.instance.adjustStock(itemId, adjustment));
    try {
      final res = await _dio!.post('/inventory/items/$itemId/adjust-stock/',
          data: {'adjustment': adjustment, 'reason': reason});
      return Item.fromJson(_norm(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to adjust stock');
    }
  }

  /// Transfers [quantity] units of [itemId] from the current branch to [toBranchId].
  /// Backend endpoint: POST /inventory/items/{id}/transfer/
  Future<void> transferStock(int itemId, int toBranchId, int quantity, String reason) async {
    if (_isLocal) throw Exception('Stock transfer not supported in local mode.');
    try {
      await _dio!.post('/inventory/items/$itemId/transfer/', data: {
        'to_branch_id': toBranchId,
        'quantity':     quantity,
        'reason':       reason,
      });
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to transfer stock');
    }
  }

  Item _toItem(Map<String, dynamic> r) => Item(
        id: r['id'] as int,
        name: r['name'] as String,
        brand: (r['brand'] as String?) ?? '',
        dosageForm: (r['dosageForm'] as String?) ?? '',
        price: (r['price'] as num).toDouble(),
        costPrice: (r['costPrice'] as num? ?? 0).toDouble(),
        markup: (r['markup'] as num? ?? 0).toDouble(),
        branchId: (r['branchId'] as num? ?? 0).toInt(),
        stock: r['stock'] as int,
        lowStockThreshold: (r['lowStockThreshold'] as int?) ?? 10,
        barcode: (r['barcode'] as String?) ?? '',
        expiryDate: r['expiryDate'] != null
            ? DateTime.tryParse(r['expiryDate'] as String) : null,
        unitOfDispensing: (r['unitOfDispensing'] as String?) ?? '',
      );
}
