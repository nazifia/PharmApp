import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores a per-device HMAC-SHA256 hash of the last successful online login.
/// Lets users authenticate offline without ever persisting a plaintext password.
class OfflineCredentialStore {
  OfflineCredentialStore._();

  static const _saltKey  = 'offline_device_salt';
  static const _hashKey  = 'offline_credential_hash';
  static const _phoneKey = 'offline_last_phone';

  static Future<String> _deviceSalt() async {
    final prefs = await SharedPreferences.getInstance();
    var salt = prefs.getString(_saltKey);
    if (salt == null) {
      final rng = Random.secure();
      salt = List.generate(32, (_) => rng.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString(_saltKey, salt);
    }
    return salt;
  }

  static String _computeHash(String phone, String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(salt));
    return hmac.convert(utf8.encode('$phone:$password')).toString();
  }

  /// Call after every successful online login.
  static Future<void> saveHash(String phone, String password) async {
    final salt = await _deviceSalt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hashKey,  _computeHash(phone, password, salt));
    await prefs.setString(_phoneKey, phone);
  }

  /// Returns true when [phone] + [password] match the cached hash.
  static Future<bool> verify(String phone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final stored      = prefs.getString(_hashKey);
    final storedPhone = prefs.getString(_phoneKey);
    if (stored == null || storedPhone != phone) return false;
    final salt = await _deviceSalt();
    return _computeHash(phone, password, salt) == stored;
  }

  /// Call on explicit logout to wipe cached credentials.
  /// Device salt is intentionally kept — it is device identity, not user data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_phoneKey);
  }
}
