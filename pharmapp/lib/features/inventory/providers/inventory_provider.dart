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
/// Screens that need live data should watch this provider.
final inventoryListProvider = FutureProvider<List<Item>>((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchAll();
});

/// Searches inventory; pass query via a family parameter.
final inventorySearchProvider =
    FutureProvider.family<List<Item>, String>((ref, query) {
  if (query.isEmpty) return ref.watch(inventoryRepositoryProvider).fetchAll();
  return ref.watch(inventoryRepositoryProvider).search(query);
});
