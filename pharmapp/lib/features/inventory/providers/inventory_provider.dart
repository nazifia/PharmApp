import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/inventory_repository.dart';
import '../../../core/network/api_client.dart';
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
