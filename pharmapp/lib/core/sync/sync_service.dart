import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background sync service — no-op stub while Isar offline cache is disabled.
/// Re-enable by importing pos_api_provider and checkout_queue_entity.
class SyncService {
  void dispose() {}
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  ref.onDispose(service.dispose);
  return service;
});
