import 'package:dio/dio.dart';
import '../../../shared/models/user.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  // 1. Initial Login Request: Send Phone, wait for OTP
  Future<void> requestOtp(String phoneNumber) async {
    try {
      final response = await _dio.post(
        '/auth/login/', // Adjust to exact Django URL
        data: {'phone_number': phoneNumber},
        options: Options(headers: {'skip_auth': true}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to send OTP: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  // 2. Verify OTP and Retrieve JWT + User Profile
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp/', // Adjust to exact Django URL
        data: {'phone_number': phoneNumber, 'otp': otpCode},
         options: Options(headers: {'skip_auth': true}),
      );
      
      if (response.statusCode == 200) {
        // Expected payload: { 'access': '...', 'refresh': '...', 'user': {...} }
        final data = response.data;
        final token = data['access'];
        final user = User.fromJson(data['user']);

        return {'token': token, 'user': user};
      } else {
         throw Exception('Invalid OTP');
      }
    } on DioException catch (e) {
       throw Exception(_handleDioError(e));
    }
  }

  // 3. Optional: Verify Token validity on app startup or refresh
  Future<User> fetchCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me/');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  String _handleDioError(DioException error) {
    if (error.response != null) {
      // Backend returned an error response (e.g., 400 Bad Request)
      if (error.response?.data is Map) {
         final message = error.response?.data['detail'] ?? error.response?.data['error'] ?? 'Unknown API Error';
         return message.toString();
      }
      return 'Received invalid status code: ${error.response?.statusCode}';
    } else {
      // Network or Timeout issue
      return 'Network Error: Please check your connection.';
    }
  }
}
