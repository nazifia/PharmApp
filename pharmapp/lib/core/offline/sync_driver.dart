import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/network/api_client.dart' show dioProvider;
import 'package:pharmapp/core/offline/app_refresh.dart';
import 'package:pharmapp/core/offline/app_restart_service.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart'
    show isOnlineProvider, checkConnectivityNow, pingServer;
import 'package:pharmapp/core/offline/eager_sync_service.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/offline/sync_service.dart';
import 'package:pharmapp/core/offline/web_online_listener.dart';
import 'package:pharmapp/core/offline/web_reload.dart';
import 'package:pharmapp/core/router/app_router.dart' show routerProvider;
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/customers/providers/customer_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/features/pos/screens/sales_history_screen.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';

/// Tracks whether an automatic sync is in flight so the offline banner can
/// reflect real state without polling [_SyncDriverState]'s private fields.
final autoSyncingProvider = StateProvider<bool>((ref) => false);

/// False while the backend is known to be unreachable — an interface that is
/// up says nothing about the server behind it, so the banner needs this as
/// well as [isOnlineProvider] to tell the truth.
final serverReachableProvider = StateProvider<bool>((ref) => true);

/// Prints the reconnect decisions to the console (browser devtools on web).
/// Temporary — flip to false once the reconnect behaviour is confirmed in the
/// field. Cheap enough to leave on: a handful of lines per minute.
const kSyncDiagnostics = true;

void _log(String message) {
  if (kSyncDiagnostics) debugPrint('[sync] $message');
}

/// Set just before a reconnect restart, read by the fresh [SyncDriver] on
/// startup. The restart discards the in-memory forceRefresh intent, so it has
/// to survive on disk or the post-reconnect refresh is silently dropped.
const _kPendingReconnectSync = 'pending_reconnect_sync';

/// Drives every automatic sync: startup, reconnect, app resume, queue changes
/// and the periodic retry.
///
/// Mounted once above the router (see main.dart) rather than inside the shell,
/// so a reconnect is still picked up while the user sits on a route that has
/// no shell — the prescriber portal, subscription, billing, superuser screens.
class SyncDriver extends ConsumerStatefulWidget {
  final Widget child;
  const SyncDriver({super.key, required this.child});

  @override
  ConsumerState<SyncDriver> createState() => _SyncDriverState();
}

class _SyncDriverState extends ConsumerState<SyncDriver>
    with WidgetsBindingObserver {
  /// Periodic fallback timer — retries sync every 15 s while items are queued.
  /// Handles environments where connectivity_plus cannot detect that the
  /// *server* came back (e.g. local dev with Django stopped/restarted, or
  /// platforms where OS-level network events are unreliable such as web/Windows).
  Timer? _retryTimer;

  /// Polls /auth/me/ every 60 s so that role/permission changes made by an
  /// admin on any user take effect without requiring a re-login. Its outcome
  /// doubles as the idle reachability check — see [_startProfilePollTimer].
  Timer? _profilePollTimer;

  /// Guards automatic sync triggers (timer, connectivity change, queue load,
  /// lifecycle resume) from running concurrently. Manual taps from the
  /// offline banner bypass this guard and use their own flag.
  bool _autoSyncing = false;

  /// Accumulates forceRefresh intent when _syncIfNeeded(forceRefresh:true) is
  /// called while a sync is already running. Consumed at the start of the next
  /// sync run so the data refresh is never silently dropped.
  bool _pendingForceRefresh = false;

  /// Last online state seen by the retry timer — used to detect offline→online
  /// transitions when connectivity_plus stream events are missed (Windows/Android).
  bool _wasOnlinePrev = true;

  /// Cancels the browser-native online/offline event subscriptions (web only;
  /// no-op on native platforms via conditional import).
  late final void Function() _cancelWebListener;

  /// Set to true when the browser/app goes offline; consumed by the online
  /// handler to decide whether a restart is needed.
  bool _wentOffline = false;

  /// Consecutive offline readings from the retry timer. Debounces
  /// connectivity_plus false negatives so one bad poll can't restart the app.
  int _offlineReadings = 0;

  /// Ticks since the backend was last probed. While the server looks healthy
  /// it is probed every fourth tick (60 s) rather than every one — enough to
  /// catch an outage the interface hides, without four requests a minute.
  int _ticksSinceProbe = 0;

  /// True once the backend has been seen unreachable. While set, the retry
  /// timer probes the server directly instead of trusting the interface state,
  /// so a reconnection is detected even when no connectivity event fires.
  bool _serverDown = false;

  /// When the app was last backgrounded — used to skip the expensive
  /// force-refresh after a brief tab-out. Null while in the foreground.
  DateTime? _backgroundedAt;

  /// How long the app must stay backgrounded before a resume is worth a
  /// full data refresh.
  static const _staleAfterBackground = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Browser-native online/offline events — more reliable than connectivity_plus
    // on web where OS-level network events may be missed.
    _log('driver mounted');
    _cancelWebListener = listenBrowserNetwork(
      onOnline: () {
        _log('browser online event');
        _handleReconnect();
      },
      onOffline: () {
        _log('browser offline event');
        _wentOffline = true;
      },
    );
    // Sync on startup: runs after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupSync());
    _startRetryTimer();
    _startProfilePollTimer();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _profilePollTimer?.cancel();
    _cancelWebListener();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Startup sync. When the previous run restarted the app because the network
  /// came back, the reconnect refresh is still owed: the restart threw away the
  /// in-memory [_pendingForceRefresh] flag, so it is read back from prefs here
  /// and replayed after a pause for the connection to settle.
  Future<void> _startupSync() async {
    final prefs = await SharedPreferences.getInstance();
    final owedReconnect = prefs.getBool(_kPendingReconnectSync) ?? false;
    if (owedReconnect) await prefs.remove(_kPendingReconnectSync);
    if (!mounted) return;
    _syncIfNeeded(
      delayMs: owedReconnect ? 2500 : 0,
      forceRefresh: owedReconnect,
    );
  }

  /// Called when the network comes back (browser online event, retry timer or
  /// profile poll).
  ///
  /// On **web**: reloads the page so the Flutter app reinitialises from a clean
  /// state. The offline queue survives in localStorage (SharedPreferences).
  ///
  /// On **native**: rebuilds the ProviderScope root via [AppRestartWrapper],
  /// which is equivalent to a cold restart without killing the process.
  ///
  /// A restart only happens when we actually went offline first ([_wentOffline]).
  /// Initial-load online events are ignored.
  void _handleReconnect() {
    _log('handleReconnect (wentOffline=$_wentOffline)');
    if (!_wentOffline) {
      // Not a real reconnect — just sync as usual.
      _syncIfNeeded(delayMs: 1000, forceRefresh: true);
      return;
    }
    _wentOffline = false;
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      // The restart tears this State down, so record the owed refresh on disk;
      // the fresh SyncDriver picks it up in _startupSync().
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPendingReconnectSync, true);
      if (!mounted) return;
      _log('restarting (web=$kIsWeb)');
      if (kIsWeb) {
        // Web: reload the browser page. Tears down the tree, so do NOT touch
        // the (now-deactivating) context afterwards.
        reloadApp();
        return;
      }
      // Native: rebuild the ProviderScope root.
      AppRestartWrapper.restart(context);
    });
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      // Poll actual OS connectivity rather than the cached stream value so that
      // offline→online transitions are detected even when connectivity_plus misses
      // the change event (known issue on Windows and some Android setups).
      final hasInterface = await checkConnectivityNow();
      // An interface being up is not the same as the backend being reachable:
      // wifi stays associated while the uplink is dead (DNS fails, no browser
      // event fires), so the interface alone can never detect that outage.
      // Probe every tick while the server is known down — recovery should be
      // quick — and every fourth tick otherwise.
      final probeDue = _serverDown || ++_ticksSinceProbe >= 4;
      if (probeDue) _ticksSinceProbe = 0;
      final isOnlineNow = hasInterface && (!probeDue || await _pingServer());
      final justReconnected = isOnlineNow && !_wasOnlinePrev;
      // An outage arms the restart whichever layer failed: a dropped interface,
      // a dead uplink (interface up, DNS failing) or an unreachable backend all
      // end with the same stale app, so all three reload on recovery.
      //
      // connectivity_plus reports a spurious `none` on Windows and on some
      // Android wifi/mobile handovers, and a single slow request can look like
      // a dead server. One bad reading arming _wentOffline would restart the
      // app — a multi-second freeze with no real outage behind it — so require
      // two consecutive offline readings (30s) before believing it.
      if (!isOnlineNow) {
        _offlineReadings++;
        if (_offlineReadings >= 2) _wentOffline = true;
      } else {
        _offlineReadings = 0;
      }
      _log('tick interface=$hasInterface online=$isOnlineNow '
          'serverDown=$_serverDown offlineReadings=$_offlineReadings '
          'wentOffline=$_wentOffline reconnected=$justReconnected');
      _wasOnlinePrev = isOnlineNow;
      if (justReconnected) {
        _handleReconnect();
      } else {
        _syncIfNeeded();
      }
    });
  }

  /// One cheap GET against the backend. Returns whether it answered.
  Future<bool> _pingServer() async {
    if (!mounted) return false;
    return _setServerDown(!await pingServer(ref.read(dioProvider)));
  }

  /// Records backend reachability and mirrors it into [serverReachableProvider]
  /// so the offline banner reflects a dead server, not just a dead interface.
  /// Returns whether the server is reachable.
  bool _setServerDown(bool down) {
    _serverDown = down;
    if (mounted) ref.read(serverReachableProvider.notifier).state = !down;
    return !down;
  }

  void _startProfilePollTimer() {
    _profilePollTimer?.cancel();
    _profilePollTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!mounted) return;
      // The poll is a request to /auth/me/ either way, so its outcome is a free
      // reachability check. Without it, a backend that dies while the queue is
      // empty and the user is idle goes unnoticed until the next write fails.
      final reachable =
          await ref.read(authFlowProvider.notifier).refreshProfile();
      if (!mounted) return;
      _log('profile poll reachable=$reachable');
      final wasDown = _serverDown;
      _setServerDown(!reachable);
      if (reachable && wasDown) _handleReconnect();
    });
  }

  /// Triggered when the app returns to the foreground from the background.
  /// Handles the case where connectivity was restored while the app was
  /// backgrounded and no stream event will fire on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final awayFor = _backgroundedAt == null
        ? Duration.zero
        : DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;

    // A force-refresh invalidates every data provider, which fires a dozen
    // requests at once. The backend serves them from a single worker, so the
    // burst serialises and the UI waits on all of it. A quick tab-out doesn't
    // make the data stale enough to be worth that — only pay for it after a
    // real absence. Shorter trips still sync the offline queue.
    _syncIfNeeded(forceRefresh: awayFor >= _staleAfterBackground);
  }

  void _invalidateAllDataProviders() {
    ref.invalidate(salesListProvider);
    ref.invalidate(offlineSalesProvider);
    ref.invalidate(salesReportProvider);
    ref.invalidate(profitReportProvider);
    ref.invalidate(cashierSalesReportProvider);
    ref.invalidate(inventoryReportProvider);
    ref.invalidate(customerReportProvider);
    ref.invalidate(inventoryListProvider);
    ref.invalidate(retailInventoryProvider);
    ref.invalidate(wholesaleInventoryProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(paymentRequestsPreloadProvider);
    ref.invalidate(dispensingLogProvider);
    ref.invalidate(dispensingStatsProvider);
  }

  /// Sync pending offline items if the device is online.
  /// [delayMs] adds a stabilisation pause so the connection is ready.
  /// [forceRefresh] invalidates all data providers even when the queue was
  /// empty — used on reconnect so screens always reload fresh data from the backend.
  /// Guarded by [_autoSyncing] so concurrent automatic triggers don't overlap.
  ///
  /// If [forceRefresh] is true but [_autoSyncing] is already running, the
  /// intent is saved in [_pendingForceRefresh] and consumed by the running sync
  /// once it completes, so the data refresh is never silently dropped.
  Future<void> _syncIfNeeded({int delayMs = 0, bool forceRefresh = false}) async {
    // Always accumulate the intent even if blocked — it will be consumed
    // by the currently-running sync when it finishes.
    if (forceRefresh) _pendingForceRefresh = true;
    if (_autoSyncing) return;
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (!mounted) return;
    // Re-check after the delay — a timer or queue-change sync may have started
    // and completed during the wait window, leaving _autoSyncing already set.
    if (_autoSyncing) return;

    // We intentionally do NOT gate on isOnlineProvider here.
    //
    // Reason: connectivity_plus streams can miss events on Windows and some web
    // environments, leaving isOnlineProvider stuck at "offline" even after
    // connectivity is restored. Rather than relying on the potentially-stale
    // stream value, we let syncAll() attempt the network calls and handle
    // connection failures gracefully (DioException with response==null).
    // syncAll() does NOT increment attempt counts for connection-level
    // failures, so queued items stay clean during offline periods.
    //
    // NOTE: intentionally do NOT short-circuit on empty queue here.
    // On startup, OfflineQueueNotifier._reload() is async — the queue state
    // may still be [] even though SharedPreferences has items. syncAll() reads
    // the queue at call time and fast-exits when empty (no network calls made).
    // Checking hasPending here would cause a race-condition false-negative that
    // silently skips the sync until the periodic timer fires.

    // Consume the accumulated flag. Also absorb any forceRefresh that arrives
    // DURING the sync (set in finally block below).
    var effectiveForceRefresh = _pendingForceRefresh;
    _pendingForceRefresh = false;

    _autoSyncing = true;
    if (mounted) ref.read(autoSyncingProvider.notifier).state = true;
    SyncResult result;
    try {
      result = await ref.read(syncServiceProvider).syncAll();
    } finally {
      // Absorb any forceRefresh that was requested while we were syncing.
      if (_pendingForceRefresh) {
        effectiveForceRefresh = true;
        _pendingForceRefresh = false;
      }
      _autoSyncing = false;
      if (mounted) ref.read(autoSyncingProvider.notifier).state = false;
    }
    // Remember whether the backend answered. syncAll() with empty queues makes
    // no network call at all, so only a run that did work can clear the flag.
    _log('sync synced=${result.synced} failed=${result.failed} '
        'connectionFailed=${result.connectionFailed} '
        'authExpired=${result.authExpired} forceRefresh=$effectiveForceRefresh'
        '${result.failureDetail == null ? '' : ' — ${result.failureDetail}'}');
    if (result.connectionFailed) {
      _setServerDown(true);
    } else if (result.hasWork) {
      _setServerDown(false);
    }
    if (!mounted) return;

    final didRefresh =
        result.synced > 0 || (effectiveForceRefresh && !result.connectionFailed);
    if (didRefresh) {
      _invalidateAllDataProviders();
      // Re-warm the offline cache so the app is ready for the next disconnection.
      ref.read(eagerSyncProvider.notifier).warmCache();
    } else if (effectiveForceRefresh && result.connectionFailed) {
      // Network wasn't stable when we tried to force-refresh on reconnect.
      // Re-arm the flag so the next sync cycle (timer or listener) picks it up.
      _pendingForceRefresh = true;
    }

    if (result.authExpired) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: const Row(children: [
          Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Session expired — logging out. Queued items preserved.',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await ref.read(authServiceProvider).logout();
      if (!mounted) return;
      ref.read(routerProvider).go('/login');
      return;
    }

    if (result.hasWork) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: (result.failed == 0
                ? EnhancedTheme.successGreen
                : EnhancedTheme.warningAmber)
            .withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Row(children: [
          Icon(
            result.failed == 0
                ? Icons.cloud_done_rounded
                : Icons.cloud_sync_rounded,
            color: Colors.black,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.failed == 0
                  ? '${result.synced} offline operation${result.synced == 1 ? '' : 's'} synced successfully'
                  : '${result.synced} synced, ${result.failed} still pending',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
    } else if (effectiveForceRefresh && didRefresh) {
      // Back online with no pending queue — show a brief confirmation.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: const Row(children: [
          Icon(Icons.wifi_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Back online — data refreshed',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger full sync + refresh when any screen increments the trigger counter
    // (e.g. from a pull-to-refresh gesture). This keeps sync coordination
    // centralised here rather than scattered across individual screens.
    ref.listen<int>(appRefreshTriggerProvider, (_, __) {
      _syncIfNeeded(forceRefresh: true);
    });

    // Auto-restart/sync on offline→online transition at runtime.
    // Startup and resume cases are handled via the initState post-frame callback.
    ref.listen<bool>(isOnlineProvider, (wasOnline, nowOnline) {
      if (!nowOnline || wasOnline == true) return;
      // Mark offline so _handleReconnect knows this is a real reconnect.
      // (The browser offline event may have already set this — idempotent.)
      _wentOffline = true;
      _handleReconnect();
    });

    // Trigger sync when the offline queues finish loading from SharedPreferences
    // on startup (OfflineQueueNotifier._reload() is async — it completes AFTER
    // the first frame, so the initState post-frame callback may see an empty
    // queue even though items are stored on disk). Also triggers immediately
    // when a new item is added to a non-empty queue so that momentarily-offline
    // writes are retried as soon as connectivity is back, without waiting for
    // the periodic timer.
    ref.listen<List<PendingSale>>(offlineQueueProvider, (previous, next) {
      if (next.isNotEmpty &&
          (previous == null || next.length > previous.length)) {
        _syncIfNeeded();
      }
    });
    ref.listen<List<PendingMutation>>(offlineMutationQueueProvider,
        (previous, next) {
      if (next.isNotEmpty &&
          (previous == null || next.length > previous.length)) {
        _syncIfNeeded();
      }
    });

    return widget.child;
  }
}
