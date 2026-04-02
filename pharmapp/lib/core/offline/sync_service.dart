import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
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

  /// Attempt to submit every pending sale AND every queued API mutation.
  /// Returns combined counts of successes and failures.
  Future<SyncResult> syncAll() async {
    if (_running) return const SyncResult();
    _running = true;

    int synced = 0;
    int failed = 0;

    // ── 1. Replay POS sales ──────────────────────────────────────────────────
    final saleNotifier = _ref.read(offlineQueueProvider.notifier);
    final sales = List.of(_ref.read(offlineQueueProvider));

    for (final entry in sales) {
      try {
        final payload = CheckoutPayload.fromJson(entry.payload);
        await _ref.read(posApiProvider).submitCheckout(payload);
        await saleNotifier.remove(entry.id);
        synced++;
      } catch (_) {
        await saleNotifier.markAttempt(entry.id);
        failed++;
      }
    }

    // ── 2. Replay generic API mutations (inventory / customer writes) ─────────
    final mutNotifier = _ref.read(offlineMutationQueueProvider.notifier);
    final mutations   = List.of(_ref.read(offlineMutationQueueProvider));
    final dio         = _ref.read(dioProvider);

    for (final m in mutations) {
      try {
        switch (m.method.toUpperCase()) {
          case 'POST':
            await dio.post(m.path, data: m.body);
            break;
          case 'PATCH':
            await dio.patch(m.path, data: m.body);
            break;
          case 'PUT':
            await dio.put(m.path, data: m.body);
            break;
          case 'DELETE':
            await dio.delete(m.path);
            break;
        }
        await mutNotifier.remove(m.id);
        synced++;
      } on DioException catch (_) {
        await mutNotifier.markAttempt(m.id);
        failed++;
      } catch (_) {
        await mutNotifier.markAttempt(m.id);
        failed++;
      }
    }

    _running = false;
    return SyncResult(synced: synced, failed: failed);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
