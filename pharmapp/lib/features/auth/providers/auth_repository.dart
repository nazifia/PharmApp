import 'package:dio/dio.dart';
import '../../../core/database/local_db.dart';
import '../../../shared/models/user.dart';

class AuthRepository {
  final Dio? _dio;

  /// Development: authenticates against the local SQLite database.
  /// Default admin: phone 0000000000 / password admin123
  AuthRepository.local() : _dio = null;

  /// Production: authenticates via Django REST API.
  AuthRepository.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    if (_isLocal) {
      final userData = await LocalDb.instance.authenticateUser(phoneNumber, password);
      if (userData == null) {
        throw Exception(
            'Invalid phone number or password.\n\nDefault admin:\n  Phone: 0000000000\n  Password: admin123');
      }
      final user = User(
        id: userData['id'] as int,
        phoneNumber: userData['phoneNumber'] as String,
        role: userData['role'] as String,
        isActive: userData['isActive'] as bool,
        isWholesaleOperator: userData['isWholesaleOperator'] as bool,
      );
      return {'token': 'local_${user.id}_${DateTime.now().millisecondsSinceEpoch}', 'user': user};
    }

    try {
      final res = await _dio!.post(
        '/auth/login/',
        data: {'phone_number': phoneNumber, 'password': password},
        options: Options(headers: {'skip_auth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      return {'token': data['access'] as String, 'user': User.fromJson(data['user'] as Map<String, dynamic>)};
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        throw Exception(body['detail'] ?? body['error'] ?? 'Invalid credentials');
      }
      throw Exception('Network error — check server connection');
    }
  }
}
