import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/prescriber.dart';
import 'prescriber_api_client.dart';

// ── API client ────────────────────────────────────────────────────────────────

final prescriberApiClientProvider = Provider<PrescriberApiClient>(
  (ref) => PrescriberApiClient(ref.watch(dioProvider)),
);

// ── List / search ─────────────────────────────────────────────────────────────

final prescriberListProvider =
    FutureProvider.autoDispose.family<List<Prescriber>, String>((ref, query) {
  return ref.read(prescriberApiClientProvider).fetchPrescribers(query: query);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class _PrescriberState {
  final bool isLoading;
  final Object? error;
  const _PrescriberState({this.isLoading = false, this.error});
  _PrescriberState copyWith({bool? isLoading, Object? error, bool clearError = false}) =>
      _PrescriberState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
  bool get hasError => error != null;
}

class PrescriberNotifier extends StateNotifier<_PrescriberState> {
  final PrescriberApiClient _client;
  final Ref _ref;
  PrescriberNotifier(this._client, this._ref)
      : super(const _PrescriberState());

  Future<Prescriber?> createPrescriber(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final p = await _client.createPrescriber(data);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberListProvider);
      return p;
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.response?.data?['detail'] ?? e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<Prescriber?> updatePrescriber(
      int id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final p = await _client.updatePrescriber(id, data);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberListProvider);
      return p;
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.response?.data?['detail'] ?? e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final prescriberNotifierProvider =
    StateNotifierProvider<PrescriberNotifier, _PrescriberState>((ref) {
  return PrescriberNotifier(ref.read(prescriberApiClientProvider), ref);
});
