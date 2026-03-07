import '../../shared/models/item.dart';
import '../../features/inventory/providers/inventory_api_client.dart';

/// Pure API-backed inventory repository.
/// Isar offline cache has been removed for cross-platform compatibility.
class InventoryRepository {
  final InventoryApiClient api;

  InventoryRepository(this.api);

  Future<List<Item>> fetchAll() => api.fetchInventory();

  Future<List<Item>> search(String query) async {
    final all = await api.fetchInventory();
    final q   = query.toLowerCase();
    return all.where((item) =>
        item.name.toLowerCase().contains(q) ||
        item.brand.toLowerCase().contains(q) ||
        item.barcode.contains(q)).toList();
  }

  Future<Item?> fetchByBarcode(String barcode) =>
      api.fetchItemByBarcode(barcode);
}
