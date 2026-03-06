import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/inventory_repository.dart';
import '../../../shared/models/item.dart';
import 'inventory_api_client.dart';

// Provides the singleton Inventory API client
final inventoryApiProvider = Provider<InventoryApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return InventoryApiClient(dio);
});

// Provides the local database repository
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final api = ref.watch(inventoryApiProvider);
  return InventoryRepository(isar, api);
});

// A StreamProvider to continuously watch the local database for offline-first UI
final inventoryListProvider = StreamProvider<List<Item>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  
  // Trigger a sync in the background whenever this provider is first listened to
  Future.microtask(() => repo.syncInventory());
  
  return repo.watchAllItems();
});
