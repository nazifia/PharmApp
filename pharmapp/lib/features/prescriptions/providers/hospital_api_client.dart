import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/hospital.dart';

const _kHospitalsCacheKey = 'cache_hospitals';

class HospitalApiClient {
  final Dio _dio;
  HospitalApiClient(this._dio);

  Future<void> _cache(dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHospitalsCacheKey, jsonEncode(data));
  }

  Future<dynamic> _getCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHospitalsCacheKey);
    return raw != null ? jsonDecode(raw) : null;
  }

  Future<List<Hospital>> fetchHospitals({String? query}) async {
    try {
      final params = <String, dynamic>{};
      if (query != null && query.isNotEmpty) params['search'] = query;
      final res = await _dio.get(
        '/prescriptions/hospitals/',
        queryParameters: params.isNotEmpty ? params : null,
      );
      final raw = res.data;
      final list = raw is Map && raw.containsKey('results')
          ? raw['results'] as List
          : raw as List;
      if (query == null || query.isEmpty) await _cache(list);
      return list.map((e) => Hospital.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final cached = await _getCache();
      if (cached != null) {
        return (cached as List)
            .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
  }

  Future<Hospital> createHospital(Map<String, dynamic> data) async {
    final res = await _dio.post('/prescriptions/hospitals/', data: data);
    return Hospital.fromJson(res.data as Map<String, dynamic>);
  }
}
