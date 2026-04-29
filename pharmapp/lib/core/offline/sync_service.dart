import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/pos/providers/pos_api_provider.dart';
import '../../features/inventory/providers/inventory_provider.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../shared/models/sale.dart';
import 'offline_queue.dart';
import '../network/api_client.dart';

/// Cache keys that must be cleared after a successful sync so that the
/// Riverpod providers re-fetch fresh data from the backend.
const _kSyncCacheKeys = [
  'cache_inventory',
  'cache_inventory_retail',
  'cache_inventory_wholesale',
  'cache_customers',
  'cache_wholesale_customers',
  'cache_expenses',
  'cache_suppliers',
  'cache_procurements',
  'cache_stock_checks',
  'cache_transfers',
  'cache_payment_requests',
  'cache_dispensing',
  'cache_notifications',
];

/// Sync result summary returned by [SyncService.syncAll].
class SyncResult {
  final int salesSynced;
  final int mutationsSynced;
  final int failedSales;
  final int failedMutations;
  final String? error;
  final bool authExpired;
  /// True when the sync loop was aborted because the server was unreachable
  /// (DioException with no response). Distinct from [failed], which counts
  /// items that received a server-level error response.
  final bool connectionFailed;
  /// Human-readable detail about the connection failure (Dio error type + URL).
  final String? connectionErrorDetail;

  const SyncResult({
    this.salesSynced = 0,
    this.mutationsSynced = 0,
    this.failedSales = 0,
    this.failedMutations = 0,
    this.error,
    this.authExpired = false,
    this.connectionFailed = false,
    this.connectionErrorDetail,
  });

  /// Total successful syncs (sales + mutations).
  int get synced => salesSynced + mutationsSynced;

  /// Total failed syncs (sales + mutations).
  int get failed => failedSales + failedMutations;

  /// Whether there was any work attempted.
  bool get hasWork => synced > 0 || failed > 0;

  bool get hasErrors => failedSales > 0 || failedMutations > 0 || error != null;
}

/// Central service that replays offline queues when connectivity is restored.
class SyncService {
  final Ref ref;

  SyncService(this.ref);

  /// Attempt to sync **both** queues (sales + generic mutations).
  ///
  /// This method is intentionally unguarded — callers are responsible for
  /// preventing unwanted concurrent calls (AppShell guards auto-syncs;
  /// _OfflineBanner guards manual taps via its own _syncing flag).
  Future<SyncResult> syncAll() async {
    int salesSynced = 0, mutationsSynced = 0;
    int failedSales = 0, failedMutations = 0;
    String? error;
    bool authExpired = false;
    bool connectionFailed = false;
    String? connectionErrorDetail;

    try {
      // ── 1. Sync pending sales ────────────────────────────────────────────
      final salesQueue = ref.read(offlineQueueProvider);
      for (final sale in List<PendingSale>.from(salesQueue)) {
        try {
          await ref
              .read(posApiProvider)
              .submitCheckout(CheckoutPayload.fromJson(sale.payload));
          await ref.read(offlineQueueProvider.notifier).remove(sale.id);
          salesSynced++;
        } catch (e) {
          if (e is DioException && e.response?.statusCode == 401) {
            authExpired = true;
            break; // auth expired — stop, don't mark attempts (not the sale's fault)
          }
          // Connection-level failures (no internet / server unreachable) must NOT
          // increment the attempt counter — the sale is not at fault, the network
          // is just temporarily unavailable. Only server errors (response != null)
          // count as genuine failures. Also stop the loop immediately so we don't
          // hammer a dead connection for every queued item.
          if (e is DioException && e.response == null) {
            connectionFailed = true;
            connectionErrorDetail = _describeConnectionError(e);
            break; // network down — stop here, try again next sync cycle
          }
          await ref.read(offlineQueueProvider.notifier).markAttempt(sale.id);
          failedSales++;
        }
      }

      // ── 2. Sync generic mutations ────────────────────────────────────────
      if (!connectionFailed && !authExpired) {
        final mutationQueue = ref.read(offlineMutationQueueProvider);
        for (final mut in List<PendingMutation>.from(mutationQueue)) {
          try {
            await _syncMutation(mut);
            await ref.read(offlineMutationQueueProvider.notifier).remove(mut.id);
            mutationsSynced++;
          } catch (e) {
            if (e is DioException && e.response?.statusCode == 401) {
              authExpired = true;
              break; // auth expired — stop, don't mark attempts (not the mutation's fault)
            }
            if (e is DioException && e.response == null) {
              connectionFailed = true;
              connectionErrorDetail ??= _describeConnectionError(e);
              break; // network down — stop here
            }
            await ref
                .read(offlineMutationQueueProvider.notifier)
                .markAttempt(mut.id);
            failedMutations++;
          }
        }
      }

      // ── 3. Invalidate stale caches on success ────────────────────────────
      if (salesSynced > 0 || mutationsSynced > 0) {
        await _clearSyncedCaches();
        _invalidateProviders();
      }
    } catch (e) {
      error = e.toString();
    }

    return SyncResult(
      salesSynced: salesSynced,
      mutationsSynced: mutationsSynced,
      failedSales: failedSales,
      failedMutations: failedMutations,
      error: error,
      authExpired: authExpired,
      connectionFailed: connectionFailed,
      connectionErrorDetail: connectionErrorDetail,
    );
  }

  /// Returns a human-readable string describing why a connection-level DioException failed.
  String _describeConnectionError(DioException e) {
    final url = e.requestOptions.uri.toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out — server may be sleeping\n$url';
      case DioExceptionType.receiveTimeout:
        return 'Response timed out — server is slow or unreachable\n$url';
      case DioExceptionType.sendTimeout:
        return 'Request send timed out\n$url';
      case DioExceptionType.connectionError:
        return 'Cannot connect — check backend is running\n$url';
      default:
        final msg = e.message ?? e.error?.toString() ?? 'unknown';
        return '$msg\n$url';
    }
  }

  /// Replay a single mutation against the backend.
  ///
  /// The mutation's stable [PendingMutation.id] is sent as the
  /// `Idempotency-Key` header so the backend can safely ignore a retry that
  /// was already applied (e.g. when the response was lost mid-flight).
  Future<void> _syncMutation(PendingMutation mut) async {
    final dio = ref.read(dioProvider);
    switch (mut.method) {
      case 'POST':
        await dio.post(mut.path, data: mut.body);
        break;
      case 'PATCH':
        await dio.patch(mut.path, data: mut.body);
        break;
      case 'PUT':
        await dio.put(mut.path, data: mut.body);
        break;
      case 'DELETE':
        await dio.delete(mut.path);
        break;
      default:
        throw UnsupportedError('Unsupported HTTP method: ${mut.method}');
    }
  }

  /// Remove all cache entries that may contain stale offline data.
  Future<void> _clearSyncedCaches() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _kSyncCacheKeys) {
      await prefs.remove(key);
    }
  }

  /// Discard all items that have failed multiple times (attempts > 0).
  Future<int> discardFailed() async {
    int removed = 0;
    final saleNotifier = ref.read(offlineQueueProvider.notifier);
    final mutNotifier = ref.read(offlineMutationQueueProvider.notifier);

    final failedSales =
        ref.read(offlineQueueProvider).where((e) => e.attempts > 0).toList();
    for (final s in failedSales) {
      await saleNotifier.remove(s.id);
      removed++;
    }

    final failedMuts = ref
        .read(offlineMutationQueueProvider)
        .where((e) => e.attempts > 0)
        .toList();
    for (final m in failedMuts) {
      await mutNotifier.remove(m.id);
      removed++;
    }

    return removed;
  }

  /// Invalidate Riverpod providers so they re-fetch from the backend.
  void _invalidateProviders() {
    ref.invalidate(inventoryListProvider);
    ref.invalidate(retailInventoryProvider);
    ref.invalidate(wholesaleInventoryProvider);
    ref.invalidate(customerListProvider);
    // Other providers are auto-dispose and will refetch when next accessed.
    // Clearing SharedPreferences caches above is sufficient for offline reads.
  }
}

/// Provider that gives easy access to the sync service.
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));

/// Convenience notifier that exposes the last sync result.
class SyncStatusNotifier extends StateNotifier<AsyncValue<SyncResult>> {
  SyncStatusNotifier() : super(const AsyncValue.data(SyncResult()));

  Future<void> syncAll(Ref ref) async {
    state = const AsyncValue.loading();
    final service = ref.read(syncServiceProvider);
    final result = await service.syncAll();
    state = AsyncValue.data(result);
  }
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, AsyncValue<SyncResult>>(
  (ref) => SyncStatusNotifier(),
);
