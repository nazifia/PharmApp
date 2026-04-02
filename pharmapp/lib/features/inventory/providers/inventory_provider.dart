import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/inventory_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_queue.dart';
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

/// Fetches the full inventory from the backend (all stores).
final inventoryListProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory();
});

/// Fetches only retail store inventory.
final retailInventoryProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory(store: 'retail');
});

/// Fetches only wholesale store inventory.
final wholesaleInventoryProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory(store: 'wholesale');
});

/// Searches inventory by keyword.
final inventorySearchProvider =
    FutureProvider.autoDispose.family<List<Item>, String>((ref, query) {
  return ref.watch(inventoryApiProvider).fetchInventory(search: query);
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

  Future<Item?> createItem(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
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
