import 'package:dio/dio.dart';
import '../../../shared/models/user.dart';

class AuthRepository {
  final Dio _dio;
  AuthRepository(this._dio);

  /// Authenticates with phone number + password.
  /// Expects Django response: `{ "access": "...", "user": { ... } }`
  Future<Map<String, dynamic>> login(
      String phoneNumber, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login/',
        data: {'phone_number': phoneNumber, 'password': password},
        options: Options(headers: {'skip_auth': true}),
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['access'] as String;
      final user  = User.fromJson(data['user'] as Map<String, dynamic>);
      return {'token': token, 'user': user};
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  /// Fetches the profile for the currently authenticated user.
  Future<User> fetchCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me/');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  String _handleDioError(DioException error) {
    if (error.response != null) {
      final body = error.response?.data;
      if (body is Map) {
        final msg = body['detail'] ??
            body['error'] ??
            (body['non_field_errors'] is List
                ? (body['non_field_errors'] as List).first
                : null) ??
            'Invalid credentials';
        return msg.toString();
      }
      return 'Server error ${error.response?.statusCode}';
    }
    return 'Network error: please check your connection.';
  }
}
