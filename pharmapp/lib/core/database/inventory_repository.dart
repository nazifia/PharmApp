import 'package:isar/isar.dart';
import '../../shared/models/item.dart';
import '../../shared/models/item_entity.dart';
import '../../features/inventory/providers/inventory_api_client.dart';

class InventoryRepository {
  final Isar isar;
  final InventoryApiClient api;

  InventoryRepository(this.isar, this.api);

  // 1. Fetch locally first and stream updates (Instant UI response)
  Stream<List<Item>> watchAllItems() {
    return isar.itemEntitys.where().watch(fireImmediately: true).map(
      (entities) => entities.map((e) => e.toDomain()).toList(),
    );
  }

  // 2. Search locally
  Future<List<Item>> searchItems(String query) async {
    final entities = await isar.itemEntitys
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .barcodeEqualTo(query)
        .findAll();
    return entities.map((e) => e.toDomain()).toList();
  }

  // 3. Sync from backend in background
  Future<void> syncInventory() async {
    try {
      final remoteItems = await api.fetchInventory();
      final entities = remoteItems.map((item) => ItemEntity.fromDomain(item)).toList();
      
      await isar.writeTxn(() async {
        // Clear old or perform conflict resolution here.
        // For simplicity, we PUT all, relying on replace:true for unique bar codes
        await isar.itemEntitys.putAll(entities); 
      });
      print("Inventory synced successfully to Isar.");
    } catch (e) {
      // Keep using local data, mark sync as failed for retry
      print("Offline mode: Using cached inventory. Sync Error: $e");
    }
  }
}
