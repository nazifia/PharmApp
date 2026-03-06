import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/models/checkout_queue_entity.dart';

class PosApiClient {
  final Dio _dio;

  PosApiClient(this._dio);

  // Submits a completed checkout to the Django Backend
  Future<void> submitCheckout(CheckoutPayload payload) async {
    try {
      final response = await _dio.post(
        '/pos/checkout/', // Adjust to your actual Django endpoint
        data: payload.toJson(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Checkout failed: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('API Error: ${e.response?.data}');
      } else {
        throw Exception('Network Error: Could not reach the server.');
      }
    }
  }
}

// Singleton Provider for the POS API Client
final posApiProvider = Provider<PosApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return PosApiClient(dio);
});

// A StateNotifier to handle the async loading/error states during checkout submission
class CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> processCheckout(CheckoutPayload payload) async {
    state = const AsyncValue.loading();
    try {
      final isar = _ref.read(isarProvider);
      final api = _ref.read(posApiProvider);

      // 1. Immediately save to local offline queue
      final queueEntity = CheckoutQueueEntity.fromPayload(payload);
      await isar.writeTxn(() async {
        await isar.checkoutQueueEntitys.put(queueEntity); // This is likely right based on Isar defaults (just adds 's'). Wait, the error said undefined. Let me check the generated g.dart file to see exactly how it's named. Actually, Isar usually pluralizes Entity to Entitys unless specified. Let me look at the error again.
      });

      // 2. Try to sync to Django immediately
      try {
        await api.submitCheckout(payload);
        
        // 3. Mark as synced if successful
        await isar.writeTxn(() async {
          queueEntity.isSynced = true;
          await isar.checkoutQueueEntitys.put(queueEntity);
        });
      } catch (networkError) {
         // Network failed, but we saved it locally. It's safe to return success to the UI.
         // We'll build a background sync job to process `isSynced == false` records later.
         print('Network offline. Checkout saved to local queue: $networkError');
      }
      
      state = const AsyncValue.data(null);
      return true; // Return success since it's safely queued locally
    } catch (e, st) {
      // This catches fatal local database errors where we couldn't even queue it
      state = AsyncValue.error(e, st);
      return false; 
    }
  }
}

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, AsyncValue<void>>((ref) {
  return CheckoutNotifier(ref);
});
