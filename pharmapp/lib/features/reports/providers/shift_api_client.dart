import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/shift.dart';

const _kShiftListCacheKey = 'cache_shifts';
const _kCurrentShiftCacheKey = 'cache_current_shift';

class ShiftQuery {
  final String? from;
  final String? to;
  final int? staffId;
  final int? branchId;

  const ShiftQuery({this.from, this.to, this.staffId, this.branchId});

  @override
  bool operator ==(Object other) =>
      other is ShiftQuery &&
      from == other.from &&
      to == other.to &&
      staffId == other.staffId &&
      branchId == other.branchId;

  @override
  int get hashCode => Object.hash(from, to, staffId, branchId);
}

class ShiftApiClient {
  final Dio _dio;
  ShiftApiClient(this._dio);

  Future<List<Shift>> fetchShifts({String? from, String? to, int? staffId, int? branchId}) async {
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (staffId != null) params['staff_id'] = staffId;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio.get('/pos/shifts/', queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results') ? data['results'] as List : data as List;
      // ponytail: single last-result cache, not per-query — offline shows last viewed range
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kShiftListCacheKey, jsonEncode(list));
      return list.map((j) => Shift.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kShiftListCacheKey);
        if (raw != null) {
          return (jsonDecode(raw) as List)
              .map((j) => Shift.fromJson(j as Map<String, dynamic>))
              .toList();
        }
        throw Exception('You are offline and no cached shift data is available.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load shifts');
    }
  }

  Future<Shift?> fetchCurrentShift() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _dio.get('/pos/shifts/current/');
      if (res.statusCode == 204 || res.data == null) {
        await prefs.remove(_kCurrentShiftCacheKey);
        return null;
      }
      await prefs.setString(_kCurrentShiftCacheKey, jsonEncode(res.data));
      return Shift.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 204) {
        await prefs.remove(_kCurrentShiftCacheKey);
        return null;
      }
      if (e.response == null) {
        final raw = prefs.getString(_kCurrentShiftCacheKey);
        if (raw != null) {
          return Shift.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        return null; // offline, no cached shift — don't block the UI
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to fetch current shift');
    }
  }

  Future<Shift> openShift({required double openingCash, int? branchId}) async {
    try {
      final res = await _dio.post('/pos/shifts/open/', data: {
        'opening_cash': openingCash,
        if (branchId != null && branchId > 0) 'branch_id': branchId,
      });
      return Shift.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception('Opening a shift requires an internet connection.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to open shift');
    }
  }

  Future<Shift> closeShift({required int shiftId, required double closingCash}) async {
    try {
      final res = await _dio.post('/pos/shifts/$shiftId/close/', data: {
        'closing_cash': closingCash,
      });
      return Shift.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception('Closing a shift requires an internet connection.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to close shift');
    }
  }
}

final shiftApiClientProvider = Provider<ShiftApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ShiftApiClient(dio);
});

final shiftListProvider = FutureProvider.autoDispose
    .family<List<Shift>, ShiftQuery>((ref, q) async {
  final client = ref.watch(shiftApiClientProvider);
  return client.fetchShifts(
    from: q.from,
    to: q.to,
    staffId: q.staffId,
    branchId: q.branchId,
  );
});

final currentShiftProvider = FutureProvider.autoDispose<Shift?>((ref) async {
  final client = ref.watch(shiftApiClientProvider);
  return client.fetchCurrentShift();
});

class ShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final ShiftApiClient _client;
  final Ref _ref;
  ShiftNotifier(this._client, this._ref) : super(const AsyncValue.data(null));

  Future<bool> openShift({required double openingCash, int? branchId}) async {
    state = const AsyncValue.loading();
    try {
      final shift = await _client.openShift(openingCash: openingCash, branchId: branchId);
      state = AsyncValue.data(shift);
      _ref.invalidate(currentShiftProvider);
      _ref.invalidate(shiftListProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> closeShift({required int shiftId, required double closingCash}) async {
    state = const AsyncValue.loading();
    try {
      final shift = await _client.closeShift(shiftId: shiftId, closingCash: closingCash);
      state = AsyncValue.data(shift);
      _ref.invalidate(currentShiftProvider);
      _ref.invalidate(shiftListProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final shiftNotifierProvider =
    StateNotifierProvider<ShiftNotifier, AsyncValue<Shift?>>((ref) {
  final client = ref.watch(shiftApiClientProvider);
  return ShiftNotifier(client, ref);
});
