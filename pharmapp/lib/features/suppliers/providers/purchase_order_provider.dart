import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/purchase_order.dart';
import 'purchase_order_api_client.dart';

final purchaseOrderApiClientProvider =
    Provider<PurchaseOrderApiClient>((ref) {
  return PurchaseOrderApiClient(ref.watch(dioProvider));
});

class PurchaseOrderListNotifier
    extends StateNotifier<AsyncValue<List<PurchaseOrder>>> {
  PurchaseOrderListNotifier(this._client)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  final PurchaseOrderApiClient _client;

  Future<void> fetch({int? supplierId}) async {
    state = const AsyncValue.loading();
    try {
      final orders = await _client.fetchOrders(supplierId: supplierId);
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<PurchaseOrder?> createOrder(Map<String, dynamic> data) async {
    try {
      final order = await _client.createOrder(data);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([order, ...current]);
      return order;
    } catch (_) {
      rethrow;
    }
  }

  Future<PurchaseOrder?> submitOrder(int id) async {
    try {
      final updated = await _client.submitOrder(id);
      _replaceInList(updated);
      return updated;
    } catch (_) {
      rethrow;
    }
  }

  Future<PurchaseOrder?> receiveOrder(
      int id, List<Map<String, dynamic>> receivedItems) async {
    try {
      final updated = await _client.receiveOrder(id, receivedItems);
      _replaceInList(updated);
      return updated;
    } catch (_) {
      rethrow;
    }
  }

  void _replaceInList(PurchaseOrder updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current
          .map((o) => o.id == updated.id ? updated : o)
          .toList(),
    );
  }
}

final purchaseOrderListProvider = StateNotifierProvider<
    PurchaseOrderListNotifier, AsyncValue<List<PurchaseOrder>>>((ref) {
  return PurchaseOrderListNotifier(
      ref.watch(purchaseOrderApiClientProvider));
});

final purchaseOrderDetailProvider =
    FutureProvider.autoDispose.family<PurchaseOrder, int>((ref, id) {
  return ref.watch(purchaseOrderApiClientProvider).fetchOrder(id);
});
