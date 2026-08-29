import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/features/auth/providers/auth_repository.dart';
import 'package:pharmapp/shared/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [online]=false throws a connection-level DioException (response == null),
/// which is what "the backend did not answer" looks like to the profile poll.
class _MeAdapter implements HttpClientAdapter {
  bool online = true;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!online) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(
      '{"id":1,"phoneNumber":"08000000000","role":"Admin","isActive":true,'
      '"isWholesaleOperator":false,"organizationId":3,'
      '"organizationName":"Alpha","organizationSlug":"alpha"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const cached = User(
    id: 1,
    phoneNumber: '08000000000',
    role: 'Admin',
    isActive: true,
    isWholesaleOperator: false,
    organizationId: 3,
    organizationName: 'Alpha',
    organizationSlug: 'alpha',
  );

  late _MeAdapter adapter;
  late AuthRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = _MeAdapter();
    repo = AuthRepository.remote(
      Dio(BaseOptions(baseUrl: 'http://localhost:8000/api'))
        ..httpClientAdapter = adapter,
    );
  });

  test('unreachable backend falls back to the cached user by default',
      () async {
    adapter.online = false;
    expect(await repo.fetchCurrentUser(cached), cached);
  });

  test('throwOnError surfaces an unreachable backend', () async {
    adapter.online = false;
    await expectLater(
      repo.fetchCurrentUser(cached, throwOnError: true),
      throwsA(isA<DioException>()),
    );
  });

  test('a reachable backend still returns the fresh profile', () async {
    final fresh = await repo.fetchCurrentUser(cached, throwOnError: true);
    expect(fresh.organizationName, 'Alpha');
  });
}
