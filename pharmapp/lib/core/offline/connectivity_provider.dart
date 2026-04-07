import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

/// Performs a fresh connectivity check, bypassing the cached stream.
/// Use this when the stream may have missed a connectivity-change event
/// (known issue on Windows and some web environments with connectivity_plus).
Future<bool> checkConnectivityNow() async {
  final result = await Connectivity().checkConnectivity();
  return result.any((r) => r != ConnectivityResult.none);
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

/// Callback registry for connectivity changes — used to trigger auto-sync.
typedef ConnectivityChangeCallback = void Function(bool isOnline);

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final connectivity = Connectivity();
    // Check the real current state before any change events arrive.
    final initial = await connectivity.checkConnectivity();
    state = initial.any((r) => r != ConnectivityResult.none);
    connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = state;
      state = results.any((r) => r != ConnectivityResult.none);
      if (!wasOnline && state) {
        // Transitioned from offline → online: notify listeners to trigger auto-sync.
        for (final cb in _callbacks) {
          cb(true);
        }
      }
    });
  }

  final List<ConnectivityChangeCallback> _callbacks = [];

  void onOnline(ConnectivityChangeCallback cb) {
    _callbacks.add(cb);
  }

  void removeCallback(ConnectivityChangeCallback cb) {
    _callbacks.remove(cb);
  }
}

final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>(
  (ref) => ConnectivityNotifier(),
);
