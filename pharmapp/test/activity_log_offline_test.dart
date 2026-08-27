import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/features/auth/providers/activity_log_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves one canned page, or fails at connection level.
class _Adapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> results;
  final bool offline;
  _Adapter({this.results = const [], this.offline = false});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(
      jsonEncode({'results': results}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://localhost/api'))
      ..httpClientAdapter = adapter;

Future<ActivityLogNotifier> _settled(_Adapter adapter) async {
  final notifier = ActivityLogNotifier(_dio(adapter));
  // The constructor kicks off fetch(); wait for it to land.
  for (var i = 0; i < 50 && notifier.state.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final page = [
    {
      'id': 1,
      'category': 'auth',
      'action': 'login',
      'description': 'Signed in',
      'userName': 'Ada',
      'timestamp': '2026-08-27T09:00:00Z',
    }
  ];

  test('the first page is served from cache when the link is down', () async {
    final online = await _settled(_Adapter(results: page));
    expect(online.state.logs, hasLength(1));
    expect(online.state.error, isNull);

    final offline = await _settled(_Adapter(offline: true));

    expect(offline.state.logs, hasLength(1));
    expect(offline.state.logs.first.description, 'Signed in');
    expect(offline.state.error, isNull);
  });

  test('with nothing cached it still reports the failure', () async {
    final offline = await _settled(_Adapter(offline: true));

    expect(offline.state.logs, isEmpty);
    expect(offline.state.error, isNotNull);
  });

  test('a filtered page is not answered from the unfiltered cache', () async {
    await _settled(_Adapter(results: page));

    final offline = await _settled(_Adapter(offline: true));
    offline.setSearch('nothing-matches');
    for (var i = 0; i < 50 && offline.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Cached logs would be a lie here — the filter was never applied to them.
    expect(offline.state.error, isNotNull);
  });
}
