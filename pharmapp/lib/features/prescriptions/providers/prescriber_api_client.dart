import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/prescriber.dart';
import '../../../shared/models/prescriber_commission.dart';
import '../../../shared/models/customer.dart';

const _kPrescribersCacheKey = 'cache_prescribers';

class PrescriberApiClient {
  final Dio _dio;
  final String? prescriberToken;

  PrescriberApiClient(this._dio, {this.prescriberToken});

  // Used for the portal endpoint — carries the prescriber signed token.
  // Token goes in X-Prescriber-Token, NOT Authorization, so that simplejwt's
  // JWTAuthentication doesn't try to validate it and return 401.
  Options _portalOpts() => Options(headers: {
        'skip_auth': true,
        if (prescriberToken != null) 'X-Prescriber-Token': prescriberToken,
      });

  Future<void> _cache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<dynamic> _getCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw != null ? jsonDecode(raw) : null;
  }

  Future<List<Prescriber>> fetchPrescribers({
    String? query,
    int? hospitalId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (query != null && query.isNotEmpty) params['search'] = query;
      if (hospitalId != null) params['hospital_id'] = hospitalId;
      final res = await _dio.get('/prescriptions/prescribers/',
          queryParameters: params.isNotEmpty ? params : null);
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      if (query == null || query.isEmpty) {
        await _cache(_kPrescribersCacheKey, list);
      }
      return list
          .map((e) => Prescriber.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final cached = await _getCache(_kPrescribersCacheKey);
      if (cached != null) {
        return (cached as List)
            .map((e) => Prescriber.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
  }

  Future<Prescriber> createPrescriber(Map<String, dynamic> data) async {
    final res = await _dio.post('/prescriptions/prescribers/', data: data);
    return Prescriber.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Prescriber> registerPrescriber(Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/prescriptions/prescribers/register/',
      data: data,
      options: Options(headers: {'skip_auth': true}),
    );
    return Prescriber.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns (prescriber, token). Token may be null if backend omits it.
  Future<(Prescriber, String?)> loginPrescriber(
      String phone, String password) async {
    final res = await _dio.post(
      '/prescriptions/prescribers/login/',
      data: {'phone': phone, 'password': password},
      options: Options(headers: {'skip_auth': true}),
    );
    final data = res.data as Map<String, dynamic>;
    final prescriber =
        Prescriber.fromJson(data['prescriber'] as Map<String, dynamic>);
    final token = (data['token'] ?? data['access']) as String?;
    return (prescriber, token);
  }

  Future<Prescriber> updatePrescriber(int id, Map<String, dynamic> data) async {
    final res =
        await _dio.patch('/prescriptions/prescribers/$id/', data: data);
    return Prescriber.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Customer>> fetchPatients(int prescriberId) async {
    final res = await _dio.get(
      '/prescriptions/prescribers/$prescriberId/patients/',
      options: _portalOpts(),
    );
    final data = res.data;
    final list = data is Map && data.containsKey('results')
        ? data['results'] as List
        : data as List;
    return list
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> registerPatient(
      int prescriberId, Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/prescriptions/prescribers/$prescriberId/patients/',
      data: data,
      options: _portalOpts(),
    );
    return Customer.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> submitPrescription(
      Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/prescriptions/portal/',
      data: data,
      options: _portalOpts(),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<CommissionSummary> fetchCommissionSummary(int prescriberId) async {
    try {
      final res = await _dio.get(
        '/prescriptions/prescribers/$prescriberId/commissions/summary/',
        options: prescriberToken != null ? _portalOpts() : null,
      );
      return CommissionSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Auth/permission errors should surface — only swallow network/timeout.
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) rethrow;
      return CommissionSummary.zero;
    }
  }

  Future<List<PrescriberCommission>> fetchCommissions(int prescriberId) async {
    try {
      final res = await _dio.get(
        '/prescriptions/prescribers/$prescriberId/commissions/',
        options: prescriberToken != null ? _portalOpts() : null,
      );
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list
          .map((e) => PrescriberCommission.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      rethrow;
    }
  }

  Future<PrescriberCommission?> markCommissionPaid(
      int prescriberId, int commissionId) async {
    final res = await _dio.patch(
      '/prescriptions/prescribers/$prescriberId/commissions/$commissionId/',
      data: {'status': 'paid'},
    );
    return PrescriberCommission.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns number of commissions marked paid and total amount.
  Future<Map<String, dynamic>> markAllCommissionsPaid(int prescriberId) async {
    final res = await _dio.post(
      '/prescriptions/prescribers/$prescriberId/commissions/pay-all/',
    );
    return res.data as Map<String, dynamic>;
  }
}
