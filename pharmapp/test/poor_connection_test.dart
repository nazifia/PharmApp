import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/network/api_client.dart';

/// Adapter that plays back a scripted list of outcomes, one per attempt.
/// Each entry is either an int status code or a [DioExceptionType] to throw.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<Object> script;
  int calls = 0;
  _ScriptedAdapter(this.script);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final step = script[calls.clamp(0, script.length - 1)];
    calls++;
    if (step is DioExceptionType) {
      throw DioException(requestOptions: options, type: step);
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      step as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(ProviderContainer c, _ScriptedAdapter adapter) {
  final dio = c.read(dioProvider);
  dio.httpClientAdapter = adapter;
  return dio;
}

/// Hands the test a [Ref] so it can call ref-taking helpers directly.
final _refProbeProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('GET retries a timeout and succeeds', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final adapter = _ScriptedAdapter([DioExceptionType.connectionTimeout, 200]);

    final res = await _dioWith(c, adapter).get<dynamic>('/ping/');

    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
    expect(c.read(networkDegradedProvider), isFalse);
  });

  test('exhausted 503 surfaces as a connection error and flags degraded',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final adapter = _ScriptedAdapter([503]);

    await expectLater(
      _dioWith(c, adapter).get<dynamic>('/ping/'),
      throwsA(isA<DioException>()
          // No response == every offline fallback in the app fires.
          .having((e) => e.response, 'response', isNull)
          .having((e) => e.type, 'type', DioExceptionType.connectionError)),
    );
    expect(adapter.calls, 3); // initial + 2 retries
    expect(c.read(networkDegradedProvider), isTrue);
  });

  test('POST without an idempotency key is never replayed', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final adapter = _ScriptedAdapter([DioExceptionType.connectionTimeout]);

    await expectLater(
      _dioWith(c, adapter).post<dynamic>('/sales/', data: {'x': 1}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
    expect(c.read(networkDegradedProvider), isTrue);
  });

  test('abortIfNetworkDegraded only fires while degraded', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // Healthy link: the write is allowed through to the network.
    expect(() => abortIfNetworkDegraded(c.read(_refProbeProvider), '/customers/'), returnsNormally);

    c.read(networkDegradedProvider.notifier).state = true;
    expect(
      () => abortIfNetworkDegraded(c.read(_refProbeProvider), '/customers/'),
      // response == null is what makes the caller's offline branch queue it.
      throwsA(isA<DioException>()
          .having((e) => e.response, 'response', isNull)
          .having((e) => e.type, 'type', DioExceptionType.connectionError)),
    );
  });

  test('a later success clears the degraded flag', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(networkDegradedProvider.notifier).state = true;

    await _dioWith(c, _ScriptedAdapter([200])).get<dynamic>('/ping/');

    expect(c.read(networkDegradedProvider), isFalse);
  });

  test('a keyed POST is replayed — the backend dedupes it', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final adapter = _ScriptedAdapter([DioExceptionType.connectionTimeout, 201]);

    final res = await _dioWith(c, adapter).post<dynamic>(
      '/pos/checkout/',
      data: {'total': 1},
      options: Options(headers: await idempotencyHeader('42')),
    );

    expect(res.statusCode, 201);
    expect(adapter.calls, 2);
  });

  test('the idempotency key is stable across calls for one install', () async {
    final first = await idempotencyHeader('42');
    final second = await idempotencyHeader('42');
    final other = await idempotencyHeader('43');

    expect(first['Idempotency-Key'], second['Idempotency-Key']);
    expect(first['Idempotency-Key'], isNot(other['Idempotency-Key']));
    // '<install id>:<queue id>' — the install half keeps two devices that
    // queued in the same microsecond from colliding.
    expect(first['Idempotency-Key'], endsWith(':42'));
  });
}
