import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart';

/// Adapter that either answers with [status] or throws a connection-level
/// DioException (response == null), mimicking an unreachable server.
class _PingAdapter implements HttpClientAdapter {
  bool reachable = true;
  int status = 200;
  _PingAdapter();

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
  late Dio dio;
  late _PingAdapter adapter;

  setUp(() {
    adapter = _PingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api'))
      ..httpClientAdapter = adapter;
  });

  test('reachable server pings true', () async {
    expect(await pingServer(dio), isTrue);
  });

  test('401 still counts as reachable — the server answered', () async {
    adapter.status = 401;
    expect(await pingServer(dio), isTrue);
  });

  test('connection failure pings false', () async {
    adapter.reachable = false;
    expect(await pingServer(dio), isFalse);
  });
}
