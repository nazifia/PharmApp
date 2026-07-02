import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/services/auth_storage.dart';
import '../../../shared/models/prescriber.dart';
import '../../../shared/models/user.dart';

const _kCredHash       = 'offline_cred_hash';
const _kCredPhone      = 'offline_cred_phone';
const _kCredSalt       = 'offline_cred_salt';       // 32-byte random per-install salt (base64)
const _kOfflineUser    = 'offline_user_cache';      // user JSON, NOT wiped by 401 interceptor
const _kOfflineToken   = 'offline_auth_token';      // token copy, NOT wiped by 401 interceptor
                                                    // or the startup expired-JWT purge — offline
                                                    // login must survive token expiry
const _kLoginAttempts  = 'offline_login_attempts';  // consecutive wrong-password count
const _kLoginLockUntil = 'offline_login_lock_until'; // epoch-ms lockout expiry
const _kMaxAttempts    = 5;
const _kLockMinutes    = 15;

// Prescriber-specific offline credential keys (separate namespace from org user)
const _kPrescriberCredHash  = 'prescriber_offline_cred_hash';
const _kPrescriberCredPhone = 'prescriber_offline_cred_phone';
const _kPrescriberCredSalt  = 'prescriber_offline_cred_salt';
const _kPrescriberOfflineToken = 'prescriber_offline_token'; // survive logout,
const _kPrescriberOfflineData  = 'prescriber_offline_data';  // like _kOfflineUser/_kOfflineToken

class AuthRepository {
  final Dio? _dio;

  /// Development: authenticates against the local SQLite database.
  /// Default admin: phone 0000000000 / password admin123
  AuthRepository.local() : _dio = null;

  /// Production: authenticates via Django REST API.
  AuthRepository.remote(Dio dio) : _dio = dio;

  bool get _isLocal => _dio == null;

  /// Wipes the cached offline credential fingerprint + user cache for both org
  /// users and prescribers ("forget this device"). NOT called on normal logout —
  /// offline login must keep working after a logout, otherwise it is unusable
  /// (the login screen is only reachable via logout). The per-install salts are
  /// intentionally kept (device identity, not user data).
  static Future<void> clearOfflineCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCredHash);
    await prefs.remove(_kCredPhone);
    await prefs.remove(_kOfflineUser);
    await prefs.remove(_kOfflineToken);
    await prefs.remove(_kLoginAttempts);
    await prefs.remove(_kLoginLockUntil);
    await prefs.remove(_kPrescriberCredHash);
    await prefs.remove(_kPrescriberCredPhone);
    await prefs.remove(_kPrescriberOfflineToken);
    await prefs.remove(_kPrescriberOfflineData);
  }

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

    // No network interface at all — skip the doomed request (and its 10s
    // connect timeout) and go straight to the offline credential check.
    if (!await checkConnectivityNow()) {
      final result = await _tryOfflineLogin(phoneNumber, password);
      if (result != null) return result;
      final prescriberResult =
          await _tryPrescriberOfflineLogin(phoneNumber, password);
      if (prescriberResult != null) return prescriberResult;
      throw Exception('You are offline. Connect to the internet and try again.');
    }

    // Interface is up, but the network may still be dead (wifi with no
    // internet, captive portal). Race the real login against a short probe:
    // if the server hasn't answered by then AND the typed credentials match
    // the offline fingerprint, log in offline immediately instead of making
    // the user wait out the full connect timeout. If they don't match, keep
    // waiting — a slow-but-alive server must still get the final word.
    final remote = _remoteLogin(phoneNumber, password);
    try {
      return await remote.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      final offline = await _tryOfflineLogin(phoneNumber, password, silent: true)
          ?? await _tryPrescriberOfflineLogin(phoneNumber, password);
      if (offline != null) {
        remote.ignore(); // discard the still-pending request's eventual result
        return offline;
      }
      return await remote;
    }
  }

  Future<Map<String, dynamic>> _remoteLogin(
      String phoneNumber, String password) async {
    try {
      final res = await _dio!.post(
        '/auth/login/',
        data: {'phone_number': phoneNumber, 'password': password},
        options: Options(headers: {'skip_auth': true}),
      );
      final data     = res.data as Map<String, dynamic>;
      final token    = data['access'] as String;
      final userType = (data['user_type'] as String?) ?? 'org';

      // Prescriber login — cache HMAC for offline use, then return.
      if (userType == 'prescriber') {
        final prescriberJson = data['prescriber'] as Map<String, dynamic>;
        final prescriber     = Prescriber.fromJson(prescriberJson);

        final pSalt = await _getOrCreatePrescriberSalt();
        final pHash = Hmac(sha256, pSalt).convert(utf8.encode('$phoneNumber:$password')).toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPrescriberCredHash,  pHash);
        await prefs.setString(_kPrescriberCredPhone, phoneNumber);
        // Offline copies — the live prescriber_token/prescriber_data keys are
        // deleted on logout, so offline login needs its own that survive it.
        await prefs.setString(_kPrescriberOfflineToken, token);
        await prefs.setString(_kPrescriberOfflineData,  jsonEncode(prescriberJson));

        return {
          'token':           token,
          'user_type':       'prescriber',
          'prescriber':      prescriber,
          'prescriber_raw':  prescriberJson,   // raw map for AuthStorage persistence
        };
      }

      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      // Persist HMAC-SHA256 credential fingerprint for offline login.
      // Uses a per-install random salt so the hash is unique to this device
      // and cannot be attacked with precomputed rainbow tables.
      final salt  = await _getOrCreateSalt();
      final hash  = Hmac(sha256, salt).convert(utf8.encode('$phoneNumber:$password')).toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCredHash,  hash);
      await prefs.setString(_kCredPhone, phoneNumber);
      // Store user + token separately — these keys are NOT wiped by the 401
      // interceptor, so offline login can reconstruct the session even after
      // token expiry.
      await prefs.setString(_kOfflineUser, jsonEncode(user.toJson()));
      await prefs.setString(_kOfflineToken, token);
      // Successful online login clears any previous lockout state.
      await prefs.remove(_kLoginAttempts);
      await prefs.remove(_kLoginLockUntil);

      return {'token': token, 'user': user};
    } on DioException catch (e) {
      // Connection-level failure (no response) — attempt offline credential check.
      if (e.response == null) {
        final result = await _tryOfflineLogin(phoneNumber, password);
        if (result != null) return result;
        final prescriberResult = await _tryPrescriberOfflineLogin(phoneNumber, password);
        if (prescriberResult != null) return prescriberResult;
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
  ///
  /// [silent] — probe mode used while a real network login is still pending
  /// (dead-wifi race): on any failure returns null instead of throwing, and
  /// never mutates the attempt counter or lockout state, so a slow-but-alive
  /// server keeps the final word on whether the password is right.
  Future<Map<String, dynamic>?> _tryOfflineLogin(
      String phoneNumber, String password, {bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // ── Lockout check ────────────────────────────────────────────────────────
    final lockUntilMs = prefs.getInt(_kLoginLockUntil) ?? 0;
    final nowMs       = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < lockUntilMs) {
      if (silent) return null;
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
      if (silent) return null;
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
      final remaining = _kMaxAttempts - attempts;
      throw Exception('Incorrect password. $remaining offline attempt(s) remaining.');
    }

    // ── Correct credentials — restore cached session ──────────────────────
    await prefs.remove(_kLoginAttempts);
    await prefs.remove(_kLoginLockUntil);

    // Read user from the dedicated offline cache (not wiped by the 401 interceptor).
    // Fall back to the main auth storage in case of a pre-fix install.
    final offlineUserData = prefs.getString(_kOfflineUser)
        ?? await AuthStorage.read('current_user');
    if (offlineUserData == null) {
      if (silent) return null;
      throw Exception(
        'Password correct, but the offline session on this device has expired.\n'
        'Connect to the internet once to sign in again.',
      );
    }

    final user = User.fromJson(jsonDecode(offlineUserData) as Map<String, dynamic>);

    // Reuse the live token if present; otherwise fall back to the offline copy
    // (survives the 401 interceptor and the startup expired-JWT purge). An
    // expired token is fine offline — no authenticated call can succeed anyway,
    // and the first online 401 forces a proper re-login. Never fabricate one.
    final token = await AuthStorage.read('auth_token')
        ?? prefs.getString(_kOfflineToken);
    if (token == null) {
      if (silent) return null;
      // Credentials verified but no token survives on this device (pre-fix
      // install). Be explicit — the generic "you are offline" message made
      // users think their password was wrong.
      throw Exception(
        'Password correct, but the offline session on this device has expired.\n'
        'Connect to the internet once to sign in again.',
      );
    }
    return {'token': token, 'user': user};
  }

  /// Offline login for prescribers — mirrors _tryOfflineLogin but no lockout
  /// (prescriber accounts are lower-risk; lockout is handled server-side).
  Future<Map<String, dynamic>?> _tryPrescriberOfflineLogin(
      String phone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash  = prefs.getString(_kPrescriberCredHash);
    final storedPhone = prefs.getString(_kPrescriberCredPhone);
    if (storedHash == null || storedPhone != phone) return null;

    final salt      = await _getOrCreatePrescriberSalt();
    final inputHash = Hmac(sha256, salt).convert(utf8.encode('$phone:$password')).toString();
    if (inputHash != storedHash) return null;

    // Credentials match — restore cached prescriber session. Prefer the live
    // session keys; fall back to the offline copies that survive logout.
    final token = await AuthStorage.read('prescriber_token')
        ?? prefs.getString(_kPrescriberOfflineToken);
    final prescriberData = await AuthStorage.read('prescriber_data')
        ?? prefs.getString(_kPrescriberOfflineData);
    if (token == null || prescriberData == null) return null;

    final rawMap     = jsonDecode(prescriberData) as Map<String, dynamic>;
    final prescriber = Prescriber.fromJson(rawMap);
    return {
      'token':          token,
      'user_type':      'prescriber',
      'prescriber':     prescriber,
      'prescriber_raw': rawMap, // so AuthNotifier re-persists the live session keys
    };
  }

  /// Per-install HMAC salt for prescriber credentials (separate from org salt).
  Future<List<int>> _getOrCreatePrescriberSalt() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kPrescriberCredSalt);
    if (stored != null) return base64.decode(stored);
    final rng  = Random.secure();
    final salt = List<int>.generate(32, (_) => rng.nextInt(256));
    await prefs.setString(_kPrescriberCredSalt, base64.encode(salt));
    return salt;
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

  /// Updates the current user's own profile fields (username, fullname).
  /// Calls PATCH /auth/me/ and returns the updated [User].
  Future<User> updateProfile({
    required User current,
    String? username,
    String? fullname,
  }) async {
    if (_isLocal) {
      // Local dev: apply the changes to the in-memory model only.
      return current.copyWith(
        username: username ?? current.username,
        fullname: fullname ?? current.fullname,
      );
    }
    try {
      final body = <String, dynamic>{
        if (username != null) 'username': username,
        if (fullname != null) 'fullname': fullname,
      };
      final res = await _dio!.patch('/auth/me/', data: body);
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) throw Exception(body['detail'] ?? body['error'] ?? 'Update failed');
      throw Exception('Network error — check server connection');
    }
  }

  /// Updates the caller's organisation name.
  /// Calls PATCH /auth/org/ and returns the new name string.
  Future<String> updateOrgName(String name) async {
    if (_isLocal) return name;
    try {
      final res = await _dio!.patch('/auth/org/', data: {'org_name': name});
      return (res.data as Map<String, dynamic>)['org_name'] as String? ?? name;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) throw Exception(body['detail'] ?? 'Update failed');
      throw Exception('Network error — check server connection');
    }
  }

  /// Updates the caller's organisation address.
  /// Calls PATCH /auth/org/ and returns the new address string.
  Future<String> updateOrgAddress(String address) async {
    if (_isLocal) return address;
    try {
      final res = await _dio!.patch('/auth/org/', data: {'address': address});
      return (res.data as Map<String, dynamic>)['address'] as String? ?? address;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) throw Exception(body['detail'] ?? 'Update failed');
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
