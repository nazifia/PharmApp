import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/inventory/providers/inventory_api_client.dart';
import '../../features/customers/providers/customer_api_client.dart';
import '../network/api_client.dart';

enum EagerSyncPhase { idle, syncing, done, error }

class EagerSyncStatus {
  final EagerSyncPhase phase;
  final String? error;
  const EagerSyncStatus({this.phase = EagerSyncPhase.idle, this.error});
}

class EagerSyncNotifier extends StateNotifier<EagerSyncStatus> {
  final Ref _ref;
  EagerSyncNotifier(this._ref) : super(const EagerSyncStatus());

  /// Fetches all critical data and writes it to both SharedPreferences and
  /// SQLite so the app can run fully offline after the first login.
  /// Fire-and-forget — does not throw; errors are captured in state.
  Future<void> warmCache() async {
    if (state.phase == EagerSyncPhase.syncing) return;
    state = const EagerSyncStatus(phase: EagerSyncPhase.syncing);
    try {
      final dio = _ref.read(dioProvider);
      final inv = InventoryApiClient.remote(dio);
      final cust = CustomerApiClient.remote(dio);
      // Fetch all store variants — each call caches to SP + SQLite.
      await Future.wait([
        inv.fetchInventory(),
        inv.fetchInventory(store: 'retail'),
        inv.fetchInventory(store: 'wholesale'),
        cust.fetchCustomers(),
      ]);
      state = const EagerSyncStatus(phase: EagerSyncPhase.done);
    } catch (e) {
      state = EagerSyncStatus(phase: EagerSyncPhase.error, error: e.toString());
    }
  }
}

final eagerSyncProvider =
    StateNotifierProvider<EagerSyncNotifier, EagerSyncStatus>(
  (ref) => EagerSyncNotifier(ref),
);
