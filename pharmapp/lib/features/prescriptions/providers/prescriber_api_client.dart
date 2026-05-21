import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/prescriber.dart';

const _kPrescribersCacheKey = 'cache_prescribers';

class PrescriberApiClient {
  final Dio _dio;
  PrescriberApiClient(this._dio);

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

  /// Public self-registration — no JWT required.
  Future<Prescriber> registerPrescriber(Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/prescriptions/prescribers/register/',
      data: data,
      options: Options(headers: {'skip_auth': true}),
    );
    return Prescriber.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Prescriber> loginPrescriber(String phone, String password) async {
    final res = await _dio.post(
      '/prescriptions/prescribers/login/',
      data: {'phone': phone, 'password': password},
      options: Options(headers: {'skip_auth': true}),
    );
    final data = res.data as Map<String, dynamic>;
    return Prescriber.fromJson(data['prescriber'] as Map<String, dynamic>);
  }

  Future<Prescriber> updatePrescriber(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/prescriptions/prescribers/$id/', data: data);
    return Prescriber.fromJson(res.data as Map<String, dynamic>);
  }
}
