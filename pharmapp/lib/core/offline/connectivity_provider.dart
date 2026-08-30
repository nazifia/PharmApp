import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

/// Performs a fresh connectivity check, bypassing the cached stream.
/// Use this when the stream may have missed a connectivity-change event
/// (known issue on Windows and some web environments with connectivity_plus).
Future<bool> checkConnectivityNow() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  } catch (_) {
    // Plugin unavailable or platform query failed — assume online. The
    // network call itself will fail fast if we're actually offline, and
    // that failure path already falls back to the offline credential check.
    return true;
  }
}

/// Stream of raw connectivity status.
/// Emits the current state immediately on subscription (via checkConnectivity),
/// then continues streaming changes — so `isOnlineProvider` is correct on startup
/// even when no connectivity change event has fired yet.
final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((_) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// `true` when at least one interface is not [ConnectivityResult.none].
///
/// In dev mode all operations go directly to the local SQLite database, so
/// network connectivity is irrelevant — always report online to avoid
/// enqueuing operations that should be processed synchronously by LocalDb.
final isOnlineProvider = Provider<bool>((ref) {
  // Dev mode: LocalDb never fails due to network — treat as always online.
  if (ref.watch(isDevModeProvider)) return true;

  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true,
    error: (_, __) => true,
  );
});


/// False while the backend is known to be unreachable — an interface that is
/// up says nothing about the server behind it, so the banner needs this as
/// well as [isOnlineProvider] to tell the truth.
///
/// Written by the reachability probe in SyncDriver and, so the banner does not
/// wait for the next probe, by every request that fails at transport level
/// (see AuthInterceptor).
final serverReachableProvider = StateProvider<bool>((ref) => true);

/// When the backend last answered anything — stamped by [AuthInterceptor] on
/// every request that gets a reply, and by [pingServer] through it.
///
/// SyncDriver's retry timer reads this to decide whether a probe is worth
/// making: traffic that already proved the server is up in the last few
/// seconds makes the probe redundant. So a busy app pays nothing, and an idle
/// one — where a probe is the only way to notice the uplink died — pays one
/// cheap GET per tick. Null until the first answer of the session.
DateTime? lastServerContact;

/// Probes the backend itself instead of the network interface.
///
/// An interface can stay "connected" while the internet behind it is down —
/// the router's uplink drops, the laptop keeps its wifi association — and no
/// connectivity event ever fires, so the offline→online transition would be
/// missed entirely. Any HTTP answer, 401 included, means the server is up;
/// only a transport-level failure counts as down.
Future<bool> pingServer(Dio dio) async {
  try {
    await dio.get(
      '/auth/me/',
      options: Options(
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        // A token that expired during the offline stretch must not log the user
        // out just because the reachability probe was the first request back —
        // the queued items still need a session to sync under.
        extra: const {'skipTokenClear': true},
      ),
    );
    return true;
  } on DioException catch (e) {
    return e.response != null;
  } catch (_) {
    return false;
  }
}
