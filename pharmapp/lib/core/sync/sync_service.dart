import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../database/database_provider.dart';
import '../../features/pos/providers/pos_api_provider.dart';
import '../../shared/models/checkout_queue_entity.dart';

class SyncService {
  final Isar _isar;
  final PosApiClient _apiClient;
  final Connectivity _connectivity = Connectivity();
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._isar, this._apiClient) {
    // Listen to network changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
       if (results.any((r) => r != ConnectivityResult.none)) {
          triggerSync();
       }
    });

    // Also poll periodically (e.g., every 5 minutes)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      triggerSync();
    });
  }

  void dispose() {
    _syncTimer?.cancel();
  }

  Future<void> triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Check for actual connection before syncing
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        return; // No internet
      }

      // Fetch unsynced items
      final unsynced = await _isar.checkoutQueueEntitys
          .filter()
          .isSyncedEqualTo(false)
          .findAll();

      if (unsynced.isEmpty) return;

      print('SyncService: Found ${unsynced.length} offline checkouts to sync.');

      for (final entity in unsynced) {
        try {
          // Submit to Django
          await _apiClient.submitCheckout(entity.payload);

          // Mark as synced
          await _isar.writeTxn(() async {
            entity.isSynced = true;
            await _isar.checkoutQueueEntitys.put(entity); // Isar generated accessor
          });
          print('SyncService: Successfully synced checkout ${entity.id}');
        } catch (e) {
          // Keep it as unsynced for next time
          print('SyncService: Failed to sync checkout ${entity.id}: $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}

// Provider for the sync service
final syncServiceProvider = Provider<SyncService>((ref) {
  final isar = ref.watch(isarProvider);
  final api = ref.watch(posApiProvider);
  
  final service = SyncService(isar, api);
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
