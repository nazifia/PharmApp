import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/prescription.dart';

const _kPrescriptionsCacheKey = 'cache_prescriptions';

class PrescriptionApiClient {
  final Dio _dio;
  PrescriptionApiClient(this._dio);

  // ── Cache helpers ──────────────────────────────────────────────────────────

  Future<void> _cache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<dynamic> _getCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw != null ? jsonDecode(raw) : null;
  }

  // ── List prescriptions ─────────────────────────────────────────────────────

  Future<List<Prescription>> fetchPrescriptions({
    String? status,
    String? search,
    int? branchId,
  }) async {
    final cacheKey = '${_kPrescriptionsCacheKey}_${status ?? 'all'}'
        '${branchId != null ? '_b$branchId' : ''}';
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio.get('/prescriptions/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      // Only cache unfiltered requests (no search query)
      if (search == null || search.isEmpty) {
        await _cache(cacheKey, list);
      }
      return list
          .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache(cacheKey);
        if (cached is List) {
          return cached
              .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw Exception('You are offline and no cached prescription data is available.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load prescriptions');
    }
  }

  // ── Single prescription ────────────────────────────────────────────────────

  Future<Prescription> fetchPrescription(int id) async {
    final cacheKey = 'cache_prescription_$id';
    try {
      final res = await _dio.get('/prescriptions/$id/');
      final data = res.data as Map<String, dynamic>;
      await _cache(cacheKey, data);
      return Prescription.fromJson(data);
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache(cacheKey);
        if (cached is Map<String, dynamic>) return Prescription.fromJson(cached);
        throw Exception('You are offline and this prescription is not cached.');
      }
      throw Exception(e.response?.data?['detail'] ?? 'Prescription not found');
    }
  }

  // ── Create prescription ────────────────────────────────────────────────────

  Future<Prescription> createPrescription(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/prescriptions/', data: data);
      return Prescription.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to create prescription');
    }
  }

  // ── Dispense medications ───────────────────────────────────────────────────

  /// [itemIndices] — indices into medications list to dispense.
  /// If null or empty, dispenses all pending medications.
  Future<Prescription> dispensePrescription(
    int id, {
    List<int>? itemIndices,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (itemIndices != null && itemIndices.isNotEmpty) {
        body['item_indices'] = itemIndices;
      }
      final res = await _dio.patch('/prescriptions/$id/dispense/',
          data: body.isNotEmpty ? body : null);
      final updated = Prescription.fromJson(res.data as Map<String, dynamic>);
      // Invalidate detail cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_prescription_$id');
      return updated;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to dispense');
    }
  }

  // ── Prescriptions for a specific customer ─────────────────────────────────

  /// Returns all prescriptions for a customer by their ID.
  /// Pass [undispensedOnly] = true to filter to pending/partial only.
  Future<List<Prescription>> fetchCustomerPrescriptions(
    int customerId, {
    bool undispensedOnly = false,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (undispensedOnly) params['undispensed'] = '1';
      final res = await _dio.get(
        '/prescriptions/customer/$customerId/',
        queryParameters: params.isNotEmpty ? params : null,
      );
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list
          .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load prescriptions');
    }
  }

  // ── Prescriptions by phone number ──────────────────────────────────────────

  /// Looks up prescriptions by customer phone number (walk-in / POS dispensing).
  Future<List<Prescription>> fetchPrescriptionsByPhone(
    String phone, {
    bool undispensedOnly = false,
  }) async {
    final cacheKey = 'cache_rx_phone_${phone}_${undispensedOnly ? 'u' : 'a'}';
    try {
      final params = <String, dynamic>{'phone': phone};
      if (undispensedOnly) params['undispensed'] = '1';
      final res = await _dio.get('/prescriptions/by-phone/',
          queryParameters: params);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      await _cache(cacheKey, list);
      return list
          .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response == null) {
        final cached = await _getCache(cacheKey);
        if (cached is List) {
          return cached
              .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        rethrow;
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to load prescriptions');
    }
  }

  // ── Global customer search ─────────────────────────────────────────────────

  /// Searches customers across ALL subscribed pharmacies.
  Future<List<Map<String, dynamic>>> searchCustomersGlobal(String query) async {
    try {
      final res = await _dio.get('/customers/search/', queryParameters: {
        'q': query,
        'global': true,
      });
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to search customers');
    }
  }
}
