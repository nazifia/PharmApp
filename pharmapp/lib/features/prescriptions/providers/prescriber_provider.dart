import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/prescriber.dart';
import '../../../shared/models/prescriber_commission.dart';
import '../../../shared/models/customer.dart';
import 'prescriber_api_client.dart';

// ── Prescriber session token (from portal login) ──────────────────────────────

final prescriberTokenProvider = StateProvider<String?>((ref) => null);

// ── API client ────────────────────────────────────────────────────────────────

final prescriberApiClientProvider = Provider<PrescriberApiClient>((ref) {
  final token = ref.watch(prescriberTokenProvider);
  return PrescriberApiClient(ref.watch(dioProvider), prescriberToken: token);
});

// ── Signed-in prescriber session ─────────────────────────────────────────────

final currentPrescriberProvider = StateProvider<Prescriber?>((ref) => null);

// ── List / search (pharmacy-side admin view) ──────────────────────────────────

final prescriberListProvider =
    FutureProvider.autoDispose.family<List<Prescriber>, String>((ref, query) {
  return ref.read(prescriberApiClientProvider).fetchPrescribers(query: query);
});

// ── Patients registered by the logged-in prescriber ──────────────────────────

final prescriberPatientListProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
  final prescriber = ref.watch(currentPrescriberProvider);
  if (prescriber == null) return [];
  return ref.read(prescriberApiClientProvider).fetchPatients(prescriber.id);
});

// ── Shared state class ────────────────────────────────────────────────────────

class _PrescriberState {
  final bool isLoading;
  final Object? error;
  const _PrescriberState({this.isLoading = false, this.error});
  _PrescriberState copyWith(
          {bool? isLoading, Object? error, bool clearError = false}) =>
      _PrescriberState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
  bool get hasError => error != null;
}

// ── Main prescriber notifier (admin / registration / login) ───────────────────

class PrescriberNotifier extends StateNotifier<_PrescriberState> {
  final PrescriberApiClient _client;
  final Ref _ref;
  PrescriberNotifier(this._client, this._ref) : super(const _PrescriberState());

  Future<Prescriber?> createPrescriber(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final p = await _client.createPrescriber(data);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberListProvider);
      return p;
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['detail'] ?? e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<Prescriber?> loginPrescriber(String phone, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final (p, token) = await _client.loginPrescriber(phone, password);
      _ref.read(currentPrescriberProvider.notifier).state = p;
      if (token != null) {
        _ref.read(prescriberTokenProvider.notifier).state = token;
      }
      state = state.copyWith(isLoading: false);
      return p;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['detail'] ?? e.message)
          : e.message;
      state = state.copyWith(isLoading: false, error: msg);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<Prescriber?> registerPrescriber(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final p = await _client.registerPrescriber(data);
      state = state.copyWith(isLoading: false);
      return p;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['detail'] ??
              e.response!.data['non_field_errors']?.toString() ??
              e.message)
          : e.message;
      state = state.copyWith(isLoading: false, error: msg);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<Prescriber?> updatePrescriber(int id, Map<String, dynamic> data,
      {bool portal = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final p = await _client.updatePrescriber(id, data, portal: portal);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberListProvider);
      return p;
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['detail'] ?? e.message);
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

// ── Patient + prescription notifier (prescriber portal) ───────────────────────

class PrescriberPatientNotifier extends StateNotifier<_PrescriberState> {
  final Ref _ref;
  PrescriberPatientNotifier(this._ref) : super(const _PrescriberState());

  PrescriberApiClient get _client => _ref.read(prescriberApiClientProvider);

  Future<Customer?> registerPatient(Map<String, dynamic> data) async {
    final prescriber = _ref.read(currentPrescriberProvider);
    if (prescriber == null) return null;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final c = await _client.registerPatient(prescriber.id, data);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberPatientListProvider);
      return c;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['detail'] ?? e.message)
          : e.message;
      state = state.copyWith(isLoading: false, error: msg);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> submitPrescription(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _client.submitPrescription(data);
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['detail'] ?? e.message)
          : e.message;
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final prescriberPatientNotifierProvider =
    StateNotifierProvider<PrescriberPatientNotifier, _PrescriberState>((ref) {
  return PrescriberPatientNotifier(ref);
});

// ── Commission providers ──────────────────────────────────────────────────────

final prescriberCommissionSummaryProvider =
    FutureProvider.autoDispose.family<CommissionSummary, int>((ref, prescriberId) {
  return ref.read(prescriberApiClientProvider).fetchCommissionSummary(prescriberId);
});

final prescriberCommissionsProvider =
    FutureProvider.autoDispose.family<List<PrescriberCommission>, int>((ref, prescriberId) {
  return ref.read(prescriberApiClientProvider).fetchCommissions(prescriberId);
});

// ── Commission notifier (admin: mark paid) ───────────────────────────────────

class CommissionNotifier extends StateNotifier<_PrescriberState> {
  final Ref _ref;
  CommissionNotifier(this._ref) : super(const _PrescriberState());

  Future<bool> markPaid(int prescriberId, int commissionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(prescriberApiClientProvider).markCommissionPaid(prescriberId, commissionId);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberCommissionsProvider(prescriberId));
      _ref.invalidate(prescriberCommissionSummaryProvider(prescriberId));
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['detail'] ?? e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Marks all pending commissions paid. Returns (paidCount, totalAmount) or null on error.
  Future<(int, double)?> markAllPaid(int prescriberId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _ref.read(prescriberApiClientProvider).markAllCommissionsPaid(prescriberId);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(prescriberCommissionsProvider(prescriberId));
      _ref.invalidate(prescriberCommissionSummaryProvider(prescriberId));
      final count  = (data['paid_count'] as num?)?.toInt() ?? 0;
      final amount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
      return (count, amount);
    } on DioException catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['detail'] ?? e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final commissionNotifierProvider =
    StateNotifierProvider<CommissionNotifier, _PrescriberState>((ref) {
  return CommissionNotifier(ref);
});
