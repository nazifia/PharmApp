import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/sale.dart';

class PosApiClient {
  final Dio _dio;

  PosApiClient(this._dio);

  /// Submits a completed checkout to the Django backend.
  Future<void> submitCheckout(CheckoutPayload payload) async {
    try {
      final response = await _dio.post(
        '/pos/checkout/',
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

final posApiProvider = Provider<PosApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return PosApiClient(dio);
});

/// Handles the async state for a checkout submission.
class CheckoutNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> processCheckout(CheckoutPayload payload) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(posApiProvider).submitCheckout(payload);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, AsyncValue<void>>((ref) {
  return CheckoutNotifier(ref);
});
