import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers /auth/refresh/ with [status] and [body].
class _RefreshAdapter implements HttpClientAdapter {
  int status = 200;
  String body = '{"access":"new-access","refresh":"rotated-refresh"}';

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (status >= 400) {
      throw DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
      );
    }
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RefreshAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RefreshAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api'))
      ..httpClientAdapter = adapter;
  });

  test('no stored refresh token — nothing to renew', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await refreshAccessToken('http://x', client: dio), isNull);
  });

  test('renews the access token and keeps the rotated refresh token', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'old-access',
      'refresh_token': 'old-refresh',
    });
    expect(await refreshAccessToken('http://x', client: dio), 'new-access');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'new-access');
    expect(prefs.getString('refresh_token'), 'rotated-refresh');
  });

  test('rejected refresh token leaves the stored session untouched', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'old-access',
      'refresh_token': 'expired-refresh',
    });
    adapter.status = 401;
    expect(await refreshAccessToken('http://x', client: dio), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'old-access');
  });
}
