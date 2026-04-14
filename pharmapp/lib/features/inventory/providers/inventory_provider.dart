import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/inventory_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../features/branches/providers/branch_provider.dart';
import '../../../shared/models/item.dart';
import 'inventory_api_client.dart';

final inventoryApiProvider = Provider<InventoryApiClient>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return InventoryApiClient.local();
  return InventoryApiClient.remote(ref.watch(dioProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final api = ref.watch(inventoryApiProvider);
  return InventoryRepository(api);
});

/// Returns the effective branch ID to scope inventory requests.
/// Returns null for org-wide access (sentinel id == -1 means "All Branches").
int? _effectiveBranchId(Ref ref) {
  final branch = ref.watch(activeBranchProvider);
  if (branch == null || branch.id <= 0) return null;
  return branch.id;
}

/// Fetches the full inventory from the backend (all stores), scoped to active branch.
final inventoryListProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory(
    branchId: _effectiveBranchId(ref),
  );
});

/// Fetches only retail store inventory, scoped to active branch.
final retailInventoryProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory(
    store: 'retail',
    branchId: _effectiveBranchId(ref),
  );
});

/// Fetches only wholesale store inventory, scoped to active branch.
final wholesaleInventoryProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory(
    store: 'wholesale',
    branchId: _effectiveBranchId(ref),
  );
});

/// Searches inventory by keyword, scoped to active branch.
final inventorySearchProvider =
    FutureProvider.autoDispose.family<List<Item>, String>((ref, query) {
  return ref.watch(inventoryApiProvider).fetchInventory(
    search: query,
    branchId: _effectiveBranchId(ref),
  );
});

/// Single item by ID.
final itemDetailProvider = FutureProvider.autoDispose.family<Item, int>((ref, id) {
  return ref.watch(inventoryApiProvider).fetchById(id);
});

// ── Inventory write notifier (offline-aware) ─────────────────────────────────

class InventoryNotifier extends StateNotifier<AsyncValue<void>> {
  final InventoryApiClient _api;
  final Ref _ref;

  InventoryNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  // ── Cache patch helpers ────────────────────────────────────────────────────

  /// Add or replace an item in an inventory list cache key.
  Future<void> _patchListCache(String key, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    final list = raw != null ? List<dynamic>.from(jsonDecode(raw) as List) : <dynamic>[];
    list.add(item);
    await prefs.setString(key, jsonEncode(list));
  }

  Future<void> _updateListCache(String key, int id, Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List);
    for (int i = 0; i < list.length; i++) {
      final item = list[i] as Map<String, dynamic>;
      if (item['id'] == id) {
        list[i] = {...item, ...updates};
        break;
      }
    }
    await prefs.setString(key, jsonEncode(list));
  }

  Future<void> _removeFromListCache(String key, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List)
        .where((e) => (e as Map<String, dynamic>)['id'] != id)
        .toList();
    await prefs.setString(key, jsonEncode(list));
  }

  /// Returns branch cache segment for the currently active branch.
  String _branchSegment() {
    final branch = _ref.read(activeBranchProvider);
    if (branch == null || branch.id <= 0) return '';
    return '_b${branch.id}';
  }

  Future<void> _patchAllInventoryCaches(Map<String, dynamic> item) async {
    final store = item['store'] as String? ?? '';
    final bs = _branchSegment();
    await _patchListCache('cache_inventory$bs', item);
    if (store == 'retail')    await _patchListCache('cache_inventory${bs}_retail', item);
    if (store == 'wholesale') await _patchListCache('cache_inventory${bs}_wholesale', item);
  }

  Future<void> _updateAllInventoryCaches(int id, Map<String, dynamic> updates) async {
    final bs = _branchSegment();
    for (final key in [
      'cache_inventory$bs',
      'cache_inventory${bs}_retail',
      'cache_inventory${bs}_wholesale',
    ]) {
      await _updateListCache(key, id, updates);
    }
    final prefs = await SharedPreferences.getInstance();
    final detailRaw = prefs.getString('cache_inventory_item_$id');
    if (detailRaw != null) {
      final detail = Map<String, dynamic>.from(jsonDecode(detailRaw) as Map);
      detail.addAll(updates);
      await prefs.setString('cache_inventory_item_$id', jsonEncode(detail));
    }
  }

  Future<void> _removeFromAllInventoryCaches(int id) async {
    final bs = _branchSegment();
    for (final key in [
      'cache_inventory$bs',
      'cache_inventory${bs}_retail',
      'cache_inventory${bs}_wholesale',
    ]) {
      await _removeFromListCache(key, id);
    }
  }

  // ── CRUD operations ─────────────────────────────────────────────────────────

  Future<Item?> createItem(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    // Inject active branch_id so the backend assigns the item to the correct branch.
    final branchId = _ref.read(activeBranchProvider)?.id;
    if (branchId != null && branchId > 0) data['branch_id'] = branchId;
    try {
      final item = await _api.createItem(data);
      _ref.invalidate(retailInventoryProvider);
      _ref.invalidate(wholesaleInventoryProvider);
      _ref.invalidate(inventoryListProvider);
      state = const AsyncValue.data(null);
      return item;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/inventory/items/',
          body: data,
          description: 'Create item "${data['name'] as String? ?? 'unknown'}"',
        );
        // Add temp entry to inventory caches so item appears immediately offline.
        final tempItem = {
          'id': -DateTime.now().millisecondsSinceEpoch,
          'name': data['name'] ?? '',
          'brand': data['brand'] ?? '',
          'dosageForm': data['dosage_form'] ?? data['dosageForm'] ?? '',
          'price': data['price'] ?? 0,
          'costPrice': data['cost'] ?? data['costPrice'] ?? 0,
          'branchId': data['branch_id'] ?? data['branchId'] ?? 0,
          'stock': data['stock'] ?? 0,
          'lowStockThreshold': data['low_stock_threshold'] ?? data['lowStockThreshold'] ?? 10,
          'barcode': data['barcode'] ?? '',
          'expiryDate': data['expiry_date'] ?? data['expiryDate'],
          'store': data['store'] ?? '',
          'status': 'pending_sync',
        };
        await _patchAllInventoryCaches(tempItem);
        _ref.invalidate(retailInventoryProvider);
        _ref.invalidate(wholesaleInventoryProvider);
        _ref.invalidate(inventoryListProvider);
        state = const AsyncValue.data(null);
        return null; // null signals "queued offline"
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Item?> updateItem(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final item = await _api.updateItem(id, data);
      _ref.invalidate(retailInventoryProvider);
      _ref.invalidate(wholesaleInventoryProvider);
      _ref.invalidate(inventoryListProvider);
      _ref.invalidate(itemDetailProvider(id));
      state = const AsyncValue.data(null);
      return item;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'PATCH', '/inventory/items/$id/',
          body: data,
          description: 'Update item "${data['name'] as String? ?? id}"',
        );
        // Patch all inventory caches so changes are visible offline.
        await _updateAllInventoryCaches(id, {...data, 'status': 'pending_sync'});
        _ref.invalidate(retailInventoryProvider);
        _ref.invalidate(wholesaleInventoryProvider);
        _ref.invalidate(inventoryListProvider);
        _ref.invalidate(itemDetailProvider(id));
        state = const AsyncValue.data(null);
        return null;
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteItem(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteItem(id);
      _ref.invalidate(retailInventoryProvider);
      _ref.invalidate(wholesaleInventoryProvider);
      _ref.invalidate(inventoryListProvider);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/inventory/items/$id/',
          description: 'Delete item #$id',
        );
        // Remove from all inventory caches immediately.
        await _removeFromAllInventoryCaches(id);
        _ref.invalidate(inventoryListProvider);
        _ref.invalidate(retailInventoryProvider);
        _ref.invalidate(wholesaleInventoryProvider);
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

  /// Transfers [quantity] units to another branch.
  /// Returns true = success, false = queued offline. Throws on server error.
  Future<bool> transferStock(int itemId, int toBranchId, int quantity, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _api.transferStock(itemId, toBranchId, quantity, reason);
      _ref.invalidate(retailInventoryProvider);
      _ref.invalidate(wholesaleInventoryProvider);
      _ref.invalidate(inventoryListProvider);
      _ref.invalidate(itemDetailProvider(itemId));
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/inventory/items/$itemId/transfer/',
          body: {'to_branch_id': toBranchId, 'quantity': quantity, 'reason': reason},
          description: 'Transfer $quantity units of item #$itemId → branch #$toBranchId',
        );
        // Optimistically deduct from current branch cache.
        final bs = _branchSegment();
        await _updateListCache('cache_inventory$bs', itemId, {'status': 'pending_sync'});
        _ref.invalidate(retailInventoryProvider);
        _ref.invalidate(wholesaleInventoryProvider);
        _ref.invalidate(inventoryListProvider);
        _ref.invalidate(itemDetailProvider(itemId));
        state = const AsyncValue.data(null);
        return false; // false = queued
      }
      state = AsyncValue.error(e, st);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Item?> adjustStock(int id, int adjustment, String reason) async {
    state = const AsyncValue.loading();
    try {
      final item = await _api.adjustStock(id, adjustment, reason);
      _ref.invalidate(retailInventoryProvider);
      _ref.invalidate(wholesaleInventoryProvider);
      _ref.invalidate(inventoryListProvider);
      _ref.invalidate(itemDetailProvider(id));
      state = const AsyncValue.data(null);
      return item;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/inventory/items/$id/adjust-stock/',
          body: {'adjustment': adjustment, 'reason': reason},
          description: 'Adjust stock for "$id" (${adjustment > 0 ? '+' : ''}$adjustment)',
        );
        // Optimistically apply the stock adjustment in the cache.
        await _updateAllInventoryCaches(id, {
          'status': 'pending_sync',
          // Note: we can't compute the new absolute stock here without knowing
          // the current value — the server will apply the delta on sync.
        });
        _ref.invalidate(retailInventoryProvider);
        _ref.invalidate(wholesaleInventoryProvider);
        _ref.invalidate(inventoryListProvider);
        _ref.invalidate(itemDetailProvider(id));
        state = const AsyncValue.data(null);
        return null;
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final inventoryNotifierProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<void>>((ref) {
  return InventoryNotifier(ref.watch(inventoryApiProvider), ref);
});
