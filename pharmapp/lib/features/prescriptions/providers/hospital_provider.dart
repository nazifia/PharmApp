import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/hospital.dart';
import 'hospital_api_client.dart';

final hospitalApiClientProvider = Provider<HospitalApiClient>(
  (ref) => HospitalApiClient(ref.watch(dioProvider)),
);

final hospitalListProvider =
    FutureProvider.autoDispose.family<List<Hospital>, String>((ref, query) {
  final token = ref.watch(authTokenProvider);
  if (token == null) return [];
  return ref.read(hospitalApiClientProvider).fetchHospitals(query: query);
});

class HospitalNotifier extends StateNotifier<AsyncValue<Hospital?>> {
  final HospitalApiClient _client;
  final Ref _ref;
  HospitalNotifier(this._client, this._ref) : super(const AsyncValue.data(null));

  Future<Hospital?> createHospital(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final h = await _client.createHospital(data);
      state = AsyncValue.data(h);
      _ref.invalidate(hospitalListProvider);
      return h;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? e.message ?? 'Network error';
      state = AsyncValue.error(msg, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return null;
    }
  }
}

final hospitalNotifierProvider =
    StateNotifierProvider<HospitalNotifier, AsyncValue<Hospital?>>((ref) {
  return HospitalNotifier(ref.read(hospitalApiClientProvider), ref);
});
