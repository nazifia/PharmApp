import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/database/inventory_repository.dart';
import '../../../shared/models/item.dart';
import 'inventory_api_client.dart';

final inventoryApiProvider = Provider<InventoryApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return InventoryApiClient(dio);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final api = ref.watch(inventoryApiProvider);
  return InventoryRepository(api);
});

/// Fetches the full inventory from the backend.
final inventoryListProvider = FutureProvider<List<Item>>((ref) {
  return ref.watch(inventoryApiProvider).fetchInventory();
});

/// Searches inventory by keyword.
final inventorySearchProvider =
    FutureProvider.family<List<Item>, String>((ref, query) {
  return ref.watch(inventoryApiProvider).fetchInventory(search: query);
});

/// Single item by ID.
final itemDetailProvider = FutureProvider.family<Item, int>((ref, id) {
  return ref.watch(inventoryApiProvider).fetchById(id);
});
