import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db.dart';
import '../../../core/services/auth_storage.dart';
import '../../../shared/models/user.dart';

const _kCredHash       = 'offline_cred_hash';
const _kCredPhone      = 'offline_cred_phone';
const _kCredSalt       = 'offline_cred_salt';       // 32-byte random per-install salt (base64)
const _kLoginAttempts  = 'offline_login_attempts';  // consecutive wrong-password count
const _kLoginLockUntil = 'offline_login_lock_until'; // epoch-ms lockout expiry
const _kMaxAttempts    = 5;
const _kLockMinutes    = 15;

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
      // skipTokenClear: true — a 401 here (endpoint missing or transient)
      // must NOT wipe the global auth token and silently log the user out.
      final res = await _dio!.get(
        '/auth/me/',
        options: Options(extra: {'skipTokenClear': true}),
      );
      return User.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      // Network unreachable or endpoint absent — return the cached user unchanged
      return fallback;
    }
  }

  Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    if (_isLocal) {
      final userData = await LocalDb.instance.authenticateUser(phoneNumber, password);
      if (userData == null) {
        throw Exception('Invalid phone number or password.');
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
      final token = data['access'] as String;
      final user  = User.fromJson(data['user'] as Map<String, dynamic>);

      // Persist HMAC-SHA256 credential fingerprint for offline login.
      // Uses a per-install random salt so the hash is unique to this device
      // and cannot be attacked with precomputed rainbow tables.
      final salt  = await _getOrCreateSalt();
      final hash  = Hmac(sha256, salt).convert(utf8.encode('$phoneNumber:$password')).toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCredHash,  hash);
      await prefs.setString(_kCredPhone, phoneNumber);
      // Successful online login clears any previous lockout state.
      await prefs.remove(_kLoginAttempts);
      await prefs.remove(_kLoginLockUntil);

      return {'token': token, 'user': user};
    } on DioException catch (e) {
      // Connection-level failure (no response) — attempt offline credential check.
      if (e.response == null) {
        final result = await _tryOfflineLogin(phoneNumber, password);
        if (result != null) return result;
        throw Exception('You are offline. Connect to the internet and try again.');
      }
      final body = e.response?.data;
      if (body is Map) {
        throw Exception(body['detail'] ?? body['error'] ?? 'Invalid credentials');
      }
      throw Exception('Network error — check server connection');
    }
  }

  /// Verifies [phoneNumber]+[password] against the locally stored HMAC-SHA256
  /// credential fingerprint. Enforces a lockout after [_kMaxAttempts] failures.
  ///
  /// Returns a login result map on success.
  /// Returns null if no offline credentials exist for this phone.
  /// Throws [Exception] on lockout or too many attempts (message shown to user).
  Future<Map<String, dynamic>?> _tryOfflineLogin(String phoneNumber, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // ── Lockout check ────────────────────────────────────────────────────────
    final lockUntilMs = prefs.getInt(_kLoginLockUntil) ?? 0;
    final nowMs       = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < lockUntilMs) {
      final remainingMin = ((lockUntilMs - nowMs) / 60000).ceil();
      throw Exception(
        'Too many failed attempts. Offline login locked for $remainingMin more minute(s).\n'
        'Connect to the internet to reset.',
      );
    }

    // ── Credential check ─────────────────────────────────────────────────────
    final storedHash  = prefs.getString(_kCredHash);
    final storedPhone = prefs.getString(_kCredPhone);
    if (storedHash == null || storedPhone != phoneNumber) return null;

    final salt      = await _getOrCreateSalt();
    final inputHash = Hmac(sha256, salt).convert(utf8.encode('$phoneNumber:$password')).toString();

    if (inputHash != storedHash) {
      // Wrong password — increment attempt counter; lock if threshold reached.
      final attempts = (prefs.getInt(_kLoginAttempts) ?? 0) + 1;
      if (attempts >= _kMaxAttempts) {
        await prefs.setInt(_kLoginLockUntil, nowMs + _kLockMinutes * 60 * 1000);
        await prefs.remove(_kLoginAttempts);
        throw Exception(
          'Too many failed attempts. Offline login locked for $_kLockMinutes minutes.\n'
          'Connect to the internet to reset.',
        );
      }
      await prefs.setInt(_kLoginAttempts, attempts);
      return null; // wrong password — caller shows generic "offline" error
    }

    // ── Correct credentials — restore cached session ──────────────────────
    await prefs.remove(_kLoginAttempts);
    await prefs.remove(_kLoginLockUntil);

    final token    = await AuthStorage.read('auth_token');
    final userData = await AuthStorage.read('current_user');
    if (token == null || userData == null) return null;

    final user = User.fromJson(jsonDecode(userData) as Map<String, dynamic>);
    return {'token': token, 'user': user};
  }

  /// Returns the per-install HMAC key (32 random bytes), generating it once
  /// on first call and persisting it in SharedPreferences.
  Future<List<int>> _getOrCreateSalt() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kCredSalt);
    if (stored != null) return base64.decode(stored);
    final rng  = Random.secure();
    final salt = List<int>.generate(32, (_) => rng.nextInt(256));
    await prefs.setString(_kCredSalt, base64.encode(salt));
    return salt;
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
