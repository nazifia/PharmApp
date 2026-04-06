import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/sale.dart';
import '../../features/pos/providers/pos_api_provider.dart';
import '../../features/inventory/providers/inventory_provider.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../features/reports/providers/reports_provider.dart';
import '../../features/pos/screens/sales_history_screen.dart';
import 'offline_queue.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Result
// ─────────────────────────────────────────────────────────────────────────────

class SyncResult {
  final int synced;
  final int failed;
  final bool authExpired;
  const SyncResult({this.synced = 0, this.failed = 0, this.authExpired = false});
  bool get hasWork => synced > 0 || failed > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────────────

/// Maximum number of attempts before a queued item is automatically discarded.
const _kMaxAttempts = 5;

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
    bool authExpired = false;

    try {
      // Guard: if the auth token is missing, skip network sync entirely.
      // This avoids hammering the server with unauthenticated requests when
      // the user's session has expired during an offline period.
      final token = _ref.read(authTokenProvider);
      if (token == null) {
        return const SyncResult(authExpired: true);
      }

      // ── 1. Replay POS sales ────────────────────────────────────────────────
      final saleNotifier = _ref.read(offlineQueueProvider.notifier);
      final sales = List.of(_ref.read(offlineQueueProvider));

      for (final entry in sales) {
        // Auto-discard items that have exhausted all retry attempts.
        if (entry.attempts >= _kMaxAttempts) {
          await saleNotifier.remove(entry.id);
          continue;
        }
        try {
          final payload = CheckoutPayload.fromJson(entry.payload);
          await _ref.read(posApiProvider).submitCheckout(payload);
          await saleNotifier.remove(entry.id);
          synced++;
        } on DioException catch (e) {
          // 401 means the token expired — stop immediately, don't burn retries.
          if (e.response?.statusCode == 401) {
            authExpired = true;
            await saleNotifier.markAttempt(entry.id);
            failed++;
            break;
          }
          await saleNotifier.markAttempt(entry.id);
          failed++;
        } catch (_) {
          await saleNotifier.markAttempt(entry.id);
          failed++;
        }
      }

      // If auth is expired, skip mutation replay — they'll all fail too.
      if (!authExpired) {
        // ── 2. Replay generic API mutations (inventory / customer writes) ──────
        final mutNotifier = _ref.read(offlineMutationQueueProvider.notifier);
        final mutations   = List.of(_ref.read(offlineMutationQueueProvider));
        final dio         = _ref.read(dioProvider);

        for (final m in mutations) {
          // Auto-discard items that have exhausted all retry attempts.
          if (m.attempts >= _kMaxAttempts) {
            await mutNotifier.remove(m.id);
            continue;
          }
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
          } on DioException catch (e) {
            if (e.response?.statusCode == 401) {
              authExpired = true;
              await mutNotifier.markAttempt(m.id);
              failed++;
              break;
            }
            await mutNotifier.markAttempt(m.id);
            failed++;
          } catch (_) {
            await mutNotifier.markAttempt(m.id);
            failed++;
          }
        }
      }

      // If any operations were synced successfully, clear stale SharedPreferences
      // caches AND invalidate Riverpod providers so every open screen reloads
      // fresh data from the server automatically.
      if (synced > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cache_sales_list');
        await prefs.remove('cache_payment_requests');
        for (final period in ['today', 'week', 'month', 'quarter', 'year']) {
          await prefs.remove('cache_report_sales_$period');
          await prefs.remove('cache_report_profit_$period');
        }
        await prefs.remove('cache_report_inventory');
        await prefs.remove('cache_report_customers');

        // Invalidate Riverpod providers so open screens refresh automatically.
        _ref.invalidate(inventoryListProvider);
        _ref.invalidate(retailInventoryProvider);
        _ref.invalidate(customerListProvider);
        _ref.invalidate(paymentRequestsPreloadProvider);
        _ref.invalidate(salesReportProvider);
        _ref.invalidate(profitReportProvider);
        _ref.invalidate(inventoryReportProvider);
        _ref.invalidate(customerReportProvider);
        _ref.invalidate(salesListProvider);
      }

      return SyncResult(synced: synced, failed: failed, authExpired: authExpired);
    } catch (_) {
      // Should not normally happen — all inner operations have their own
      // try/catch. This outer catch is a safety net so that _running is
      // ALWAYS reset even if something unexpected throws (e.g. provider
      // disposal, SharedPreferences I/O error). Without this, _running
      // would stay true permanently and every future sync call would silently
      // return SyncResult() with zero work done and no snackbar.
      return SyncResult(synced: synced, failed: failed, authExpired: authExpired);
    } finally {
      // CRITICAL: always reset _running regardless of how the method exits.
      _running = false;
    }
  }

  /// Remove all queue entries that have at least one failed attempt.
  Future<int> discardFailed() async {
    final saleNotifier = _ref.read(offlineQueueProvider.notifier);
    final mutNotifier  = _ref.read(offlineMutationQueueProvider.notifier);

    final failedSales = _ref.read(offlineQueueProvider)
        .where((e) => e.attempts > 0)
        .toList();
    final failedMuts  = _ref.read(offlineMutationQueueProvider)
        .where((e) => e.attempts > 0)
        .toList();

    for (final s in failedSales) { await saleNotifier.remove(s.id); }
    for (final m in failedMuts)  { await mutNotifier.remove(m.id); }

    return failedSales.length + failedMuts.length;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
