import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/core/services/auth_storage.dart';
import 'package:pharmapp/features/auth/providers/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Swappable adapter: [online]=true returns a canned login response,
/// [online]=false throws a connection-level DioException (response == null),
/// mimicking "no network".
class _FakeAdapter implements HttpClientAdapter {
  bool online = true;
  final String body;
  _FakeAdapter(this.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!online) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(body, 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const phone = '08030000000';
  const password = 'secret123';

  final userJson = {
    'id': 1,
    'phoneNumber': phone,
    'role': 'Admin',
    'isActive': true,
  };
  final loginBody = jsonEncode({'access': 'jwt-token-abc', 'user': userJson});

  late _FakeAdapter adapter;
  late Dio dio;
  late AuthRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    adapter = _FakeAdapter(loginBody);
    dio = Dio()..httpClientAdapter = adapter;
    repo = AuthRepository.remote(dio);
  });

  // Online login persists the offline credential fingerprint. The AuthNotifier
  // is what writes auth_token to AuthStorage, so the test does that explicitly
  // (the offline path reads it back).
  Future<void> doOnlineLogin() async {
    final res = await repo.login(phone, password);
    await AuthStorage.write('auth_token', res['token'] as String);
  }

  test('online login then offline login with correct password succeeds',
      () async {
    await doOnlineLogin();

    adapter.online = false;
    final res = await repo.login(phone, password);

    expect(res['token'], 'jwt-token-abc');
    expect(res['user'].phoneNumber, phone);
  });

  test('offline login with no cached credentials fails', () async {
    adapter.online = false;
    expect(() => repo.login(phone, password), throwsA(isA<Exception>()));
  });

  test('offline login with wrong password reports remaining attempts',
      () async {
    await doOnlineLogin();
    adapter.online = false;

    expect(
      () => repo.login(phone, 'wrongpass'),
      throwsA(predicate(
          (e) => e.toString().contains('attempt'))),
    );
  });

  test('offline login locks out after max failed attempts', () async {
    await doOnlineLogin();
    adapter.online = false;

    // 5 wrong attempts → the 5th throws the lockout message.
    Object? lastError;
    for (var i = 0; i < 5; i++) {
      try {
        await repo.login(phone, 'wrongpass');
      } catch (e) {
        lastError = e;
      }
    }
    expect(lastError.toString(), contains('locked'));

    // Even the correct password is now refused while locked.
    expect(
      () => repo.login(phone, password),
      throwsA(predicate((e) => e.toString().contains('locked'))),
    );
  });

  test('clearOfflineCredentials disables subsequent offline login', () async {
    await doOnlineLogin();
    await AuthRepository.clearOfflineCredentials();

    adapter.online = false;
    expect(() => repo.login(phone, password), throwsA(isA<Exception>()));
  });
}
