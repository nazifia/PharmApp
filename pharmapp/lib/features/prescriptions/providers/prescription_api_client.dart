import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/prescription.dart';

const _kPrescriptionsCacheKey = 'cache_prescriptions';

// ── Medication availability across pharmacies ──────────────────────────────────

class MedicationAvailability {
  final String pharmacyName;
  final int pharmacyId;
  final int stockQuantity;
  final String? address;
  final String? phone;

  const MedicationAvailability({
    required this.pharmacyName,
    required this.pharmacyId,
    required this.stockQuantity,
    this.address,
    this.phone,
  });

  factory MedicationAvailability.fromJson(Map<String, dynamic> j) =>
      MedicationAvailability(
        pharmacyName:
            (j['pharmacy_name'] ?? j['pharmacyName'] as String?) ?? '',
        pharmacyId: (j['pharmacy_id'] ?? j['pharmacyId'] as int?) ?? 0,
        stockQuantity:
            (j['stock_quantity'] ?? j['stockQuantity'] as int?) ?? 0,
        address: j['address'] as String?,
        phone: j['phone'] as String?,
      );
}

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
    bool networkWide = false,
  }) async {
    final cacheKey = '${_kPrescriptionsCacheKey}_${status ?? 'all'}'
        '${networkWide ? '_network' : branchId != null ? '_b$branchId' : ''}';
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (networkWide) {
        params['network_wide'] = 'true';
      } else if (branchId != null && branchId > 0) {
        params['branch_id'] = branchId;
      }
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

  // ── Update prescription metadata / status ─────────────────────────────────

  /// Updates editable fields: doctor_name, diagnosis, notes, status.
  /// Status values: 'pending' | 'partial' | 'dispensed'.
  Future<Prescription> updatePrescription(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.patch('/prescriptions/$id/', data: data);
      final updated = Prescription.fromJson(res.data as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_prescription_$id');
      return updated;
    } on DioException catch (e) {
      if (e.response == null) rethrow;
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to update prescription');
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

  // ── Medication availability across pharmacies ──────────────────────────────

  /// Returns which pharmacies in the network carry [medicationName] and their
  /// current stock level, price, address, and contact info.
  Future<List<MedicationAvailability>> fetchMedicationAvailability(
    String medicationName, {
    String? brand,
  }) async {
    try {
      final params = <String, dynamic>{'name': medicationName};
      if (brand != null && brand.isNotEmpty) params['brand'] = brand;
      final res = await _dio.get('/inventory/availability/',
          queryParameters: params);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list
          .map((e) =>
              MedicationAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'You are offline. Cannot check pharmacy availability.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to check availability');
    }
  }

  // ── Network-wide pending count ─────────────────────────────────────────────

  /// Returns pending + partial counts across the org network (no branch filter).
  /// Pass [branchId] to scope to a specific branch.
  Future<Map<String, int>> fetchPendingCount({int? branchId}) async {
    try {
      final params = <String, dynamic>{};
      if (branchId != null && branchId > 0) params['branch_id'] = branchId;
      final res = await _dio.get('/prescriptions/pending-count/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data as Map<String, dynamic>;
      return {
        'pending': (data['pending'] as num?)?.toInt() ?? 0,
        'partial': (data['partial'] as num?)?.toInt() ?? 0,
        'total':   (data['total']   as num?)?.toInt() ?? 0,
      };
    } on DioException catch (e) {
      if (e.response == null) {
        // Offline — return zeros rather than surfacing an error
        return {'pending': 0, 'partial': 0, 'total': 0};
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to fetch pending count');
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
