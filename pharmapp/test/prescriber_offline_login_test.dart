import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/core/services/auth_storage.dart';
import 'package:pharmapp/features/auth/providers/auth_repository.dart';
import 'package:pharmapp/shared/models/prescriber.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Swappable adapter: [online]=true returns a canned prescriber login response,
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
  const phone = '08055555555';
  const password = 'rxsecret123';

  final prescriberJson = {
    'id': 7,
    'name': 'Dr Ada',
    'phone': phone,
    'license_number': 'MDCN-1234',
  };
  final loginBody = jsonEncode({
    'access': 'prescriber-jwt-xyz',
    'user_type': 'prescriber',
    'prescriber': prescriberJson,
  });

  late _FakeAdapter adapter;
  late Dio dio;
  late AuthRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    adapter = _FakeAdapter(loginBody);
    dio = Dio()..httpClientAdapter = adapter;
    repo = AuthRepository.remote(dio);
  });

  // Online login caches the prescriber HMAC fingerprint. The AuthNotifier is
  // what persists prescriber_token/prescriber_data to AuthStorage, so the test
  // does that explicitly (the offline path reads them back).
  Future<void> doOnlinePrescriberLogin() async {
    final res = await repo.login(phone, password);
    expect(res['user_type'], 'prescriber');
    await AuthStorage.write('prescriber_token', res['token'] as String);
    await AuthStorage.write(
        'prescriber_data', jsonEncode(res['prescriber_raw']));
  }

  test('online prescriber login then offline login with correct password succeeds',
      () async {
    await doOnlinePrescriberLogin();

    adapter.online = false;
    final res = await repo.login(phone, password);

    expect(res['token'], 'prescriber-jwt-xyz');
    expect(res['user_type'], 'prescriber');
    expect((res['prescriber'] as Prescriber).id, 7);
    expect((res['prescriber'] as Prescriber).name, 'Dr Ada');
  });

  test('offline prescriber login with no cached credentials fails', () async {
    adapter.online = false;
    expect(() => repo.login(phone, password), throwsA(isA<Exception>()));
  });

  test('offline prescriber login with wrong password fails', () async {
    await doOnlinePrescriberLogin();
    adapter.online = false;

    // Wrong password → prescriber path returns null → no cached org user →
    // generic offline exception (no lockout / no attempt counter for prescribers).
    expect(
      () => repo.login(phone, 'wrongpass'),
      throwsA(predicate((e) => e.toString().contains('offline'))),
    );
  });

  test('prescriber offline login has no lockout after repeated failures',
      () async {
    await doOnlinePrescriberLogin();
    adapter.online = false;

    for (var i = 0; i < 6; i++) {
      try {
        await repo.login(phone, 'wrongpass');
      } catch (_) {}
    }

    // Correct password still works — no lockout applies to prescribers.
    final res = await repo.login(phone, password);
    expect(res['user_type'], 'prescriber');
    expect((res['prescriber'] as Prescriber).id, 7);
  });

  test('clearOfflineCredentials disables subsequent prescriber offline login',
      () async {
    await doOnlinePrescriberLogin();
    await AuthRepository.clearOfflineCredentials();

    adapter.online = false;
    expect(() => repo.login(phone, password), throwsA(isA<Exception>()));
  });
}
