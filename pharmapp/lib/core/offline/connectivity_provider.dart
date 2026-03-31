import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Connectivity stream
// ─────────────────────────────────────────────────────────────────────────────

/// Raw connectivity events from the OS.
/// Emits the *current* state immediately on first listen, then follows changes.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();
  // Emit current status right away so the app knows its state on startup.
  yield await connectivity.checkConnectivity();
  // Then forward all subsequent OS-level changes.
  yield* connectivity.onConnectivityChanged;
});

/// `true` when at least one interface is not [ConnectivityResult.none].
final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityStreamProvider);
  return async.when(
    data:    (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true,   // optimistic: assume online until first event
    error:   (_, __) => true,
  );
});
