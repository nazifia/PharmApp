import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart';

/// Answers with [status], or throws a connection-level DioException
/// (response == null) when [reachable] is false.
class _Adapter implements HttpClientAdapter {
  bool reachable = true;
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!reachable) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ProviderContainer container;
  late Dio dio;
  late _Adapter adapter;

  setUp(() {
    container = ProviderContainer();
    adapter = _Adapter();
    dio = container.read(dioProvider)..httpClientAdapter = adapter;
    lastServerContact = null;
  });

  tearDown(() => container.dispose());

  bool reachable() => container.read(serverReachableProvider);

  test('starts out assuming the server is reachable', () {
    expect(reachable(), isTrue);
  });

  test('a request that never reaches the server marks it unreachable',
      () async {
    adapter.reachable = false;
    await expectLater(dio.get<void>('/auth/me/'), throwsA(isA<Object>()));
    expect(reachable(), isFalse);
  });

  test('a 500 counts as reachable — the server answered', () async {
    container.read(serverReachableProvider.notifier).state = false;
    adapter.status = 500;
    await expectLater(dio.get<void>('/auth/me/'), throwsA(isA<Object>()));
    expect(reachable(), isTrue);
  });

  test('a successful request clears an earlier outage', () async {
    container.read(serverReachableProvider.notifier).state = false;
    await dio.get<void>('/auth/me/');
    expect(reachable(), isTrue);
  });

  test('an answered request stamps the last-contact time', () async {
    await dio.get<void>('/auth/me/');
    expect(lastServerContact, isNotNull);
  });

  test('a request that never reached the server leaves the stamp alone',
      () async {
    adapter.reachable = false;
    await expectLater(dio.get<void>('/auth/me/'), throwsA(isA<Object>()));
    expect(lastServerContact, isNull);
  });
}
