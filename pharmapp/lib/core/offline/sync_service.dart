import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/sale.dart';
import '../../features/pos/providers/pos_api_provider.dart';
import 'offline_queue.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Result
// ─────────────────────────────────────────────────────────────────────────────

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({this.synced = 0, this.failed = 0});
  bool get hasWork => synced > 0 || failed > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────────────

class SyncService {
  final Ref _ref;
  bool _running = false;

  SyncService(this._ref);

  /// Attempt to submit every pending sale in order.
  /// Returns counts of successes and failures.
  Future<SyncResult> syncAll() async {
    if (_running) return const SyncResult();
    _running = true;

    final notifier = _ref.read(offlineQueueProvider.notifier);
    // Snapshot the current queue so new enqueues during sync aren't touched.
    final queue = List.of(_ref.read(offlineQueueProvider));

    int synced = 0;
    int failed = 0;

    for (final entry in queue) {
      try {
        final payload = CheckoutPayload.fromJson(entry.payload);
        await _ref.read(posApiProvider).submitCheckout(payload);
        await notifier.remove(entry.id);
        synced++;
      } catch (_) {
        await notifier.markAttempt(entry.id);
        failed++;
      }
    }

    _running = false;
    return SyncResult(synced: synced, failed: failed);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
