import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:image_picker/image_picker.dart';
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

  /// Fetches the current authenticated user's profile from the backend.
  /// Returns the cached/stub user in local dev mode.
  Future<User> fetchCurrentUser(User fallback) async {
    if (_isLocal) return fallback;
    try {
      final res = await _dio!.get('/auth/me/');
      return User.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      // Network unreachable — return the cached user unchanged
      return fallback;
    }
  }

  Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    if (_isLocal) {
      final userData = await LocalDb.instance.authenticateUser(phoneNumber, password);
      if (userData == null) {
        throw Exception(
          kDebugMode
              ? 'Invalid phone number or password.\n\nDefault admin:\n  Phone: 0000000000\n  Password: admin123'
              : 'Invalid phone number or password.',
        );
      }
      final user = User(
        id: userData['id'] as int,
        phoneNumber: userData['phoneNumber'] as String,
        role: userData['role'] as String,
        isActive: userData['isActive'] as bool,
        isWholesaleOperator: userData['isWholesaleOperator'] as bool,
        organizationId: 0,
        organizationName: 'Local Dev',
        organizationSlug: 'local-dev',
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

  /// Uploads a new logo for the caller's organisation.
  /// Returns the absolute URL of the uploaded logo.
  Future<String> uploadOrgLogo(XFile imageFile) async {
    if (_isLocal) {
      throw Exception('Logo upload requires a live backend connection.');
    }
    try {
      final formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(imageFile.path, filename: imageFile.name),
      });
      final res = await _dio!.patch('/auth/org/logo/', data: formData);
      return (res.data as Map<String, dynamic>)['logoUrl'] as String;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) throw Exception(body['detail'] ?? 'Upload failed');
      throw Exception('Network error — check server connection');
    }
  }

  /// Register a new pharmacy organization + first admin user.
  /// Calls POST /auth/register-org/ (no auth header required).
  Future<Map<String, dynamic>> registerOrg({
    required String orgName,
    required String phone,
    required String password,
    String? address,
  }) async {
    if (_isLocal) {
      throw Exception('Org registration is not available in local dev mode. Switch to Production in Settings.');
    }
    try {
      final res = await _dio!.post(
        '/auth/register-org/',
        data: {
          'org_name': orgName,
          'phone_number': phone,
          'password': password,
          if (address != null && address.isNotEmpty) 'address': address,
        },
        options: Options(headers: {'skip_auth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      return {
        'token': data['access'] as String,
        'user': User.fromJson(data['user'] as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        throw Exception(body['detail'] ?? body['error'] ?? 'Registration failed');
      }
      throw Exception('Network error — check server connection');
    }
  }
}
