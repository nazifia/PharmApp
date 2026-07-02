import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/shift.dart';

const _kWsShiftListCacheKey = 'cache_ws_shifts';
const _kWsCurrentShiftCacheKey = 'cache_ws_current_shift';

class WholesaleShiftQuery {
  final String? from;
  final String? to;
  final int? staffId;

  const WholesaleShiftQuery({this.from, this.to, this.staffId});

  @override
  bool operator ==(Object other) =>
      other is WholesaleShiftQuery &&
      from == other.from &&
      to == other.to &&
      staffId == other.staffId;

  @override
  int get hashCode => Object.hash(from, to, staffId);
}

class WholesaleShiftApiClient {
  final Dio _dio;
  WholesaleShiftApiClient(this._dio);

  Future<List<Shift>> fetchShifts({String? from, String? to, int? staffId}) async {
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (staffId != null) params['staff_id'] = staffId;
      final res = await _dio.get('/pos/shifts/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      // ponytail: single last-result cache, not per-query — offline shows last viewed range
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kWsShiftListCacheKey, jsonEncode(list));
      return list.map((j) => Shift.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kWsShiftListCacheKey);
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
        await prefs.remove(_kWsCurrentShiftCacheKey);
        return null;
      }
      await prefs.setString(_kWsCurrentShiftCacheKey, jsonEncode(res.data));
      return Shift.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 204) {
        await prefs.remove(_kWsCurrentShiftCacheKey);
        return null;
      }
      if (e.response == null) {
        final raw = prefs.getString(_kWsCurrentShiftCacheKey);
        if (raw != null) {
          return Shift.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        return null; // offline, no cached shift — don't block the UI
      }
      throw Exception(e.response?.data?['detail'] ?? 'Failed to fetch current shift');
    }
  }

  Future<Shift> openShift({required double openingCash}) async {
    try {
      final res = await _dio.post('/pos/shifts/open/', data: {
        'opening_cash': openingCash,
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

final wholesaleShiftApiClientProvider = Provider<WholesaleShiftApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return WholesaleShiftApiClient(dio);
});

final wholesaleShiftListProvider = FutureProvider.autoDispose
    .family<List<Shift>, WholesaleShiftQuery>((ref, q) async {
  final client = ref.watch(wholesaleShiftApiClientProvider);
  return client.fetchShifts(from: q.from, to: q.to, staffId: q.staffId);
});

final wholesaleCurrentShiftProvider = FutureProvider.autoDispose<Shift?>((ref) async {
  final client = ref.watch(wholesaleShiftApiClientProvider);
  return client.fetchCurrentShift();
});

class WholesaleShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final WholesaleShiftApiClient _client;
  final Ref _ref;
  WholesaleShiftNotifier(this._client, this._ref) : super(const AsyncValue.data(null));

  Future<bool> openShift({required double openingCash}) async {
    state = const AsyncValue.loading();
    try {
      final shift = await _client.openShift(openingCash: openingCash);
      state = AsyncValue.data(shift);
      _ref.invalidate(wholesaleCurrentShiftProvider);
      _ref.invalidate(wholesaleShiftListProvider);
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
      _ref.invalidate(wholesaleCurrentShiftProvider);
      _ref.invalidate(wholesaleShiftListProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final wholesaleShiftNotifierProvider =
    StateNotifierProvider<WholesaleShiftNotifier, AsyncValue<Shift?>>((ref) {
  final client = ref.watch(wholesaleShiftApiClientProvider);
  return WholesaleShiftNotifier(client, ref);
});
