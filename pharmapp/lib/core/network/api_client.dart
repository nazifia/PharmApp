import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Base URL ─────────────────────────────────────────────────────────────────

/// Resolves the backend base URL for the current platform.
/// Android emulator uses 10.0.2.2 to reach host localhost.
/// Web and desktop (Windows/Linux/macOS) use localhost directly.
///
/// Run the PharmApp backend on port 8000:
///   python manage.py runserver 8000
final baseUrlProvider = StateProvider<String>((ref) {
  if (!kIsWeb) {
    // Mobile (Android/iOS) — check at runtime; default Android emulator IP
    try {
      // ignore: do_not_use_environment
      const env = String.fromEnvironment('API_URL', defaultValue: '');
      if (env.isNotEmpty) return env;
    } catch (_) {}
    return 'http://10.0.2.2:8000/api';
  }
  return 'http://localhost:8000/api';
});

// ── Auth token ────────────────────────────────────────────────────────────────

/// Holds the raw JWT access token in memory.
/// Single source of truth — imported by both api_client and auth_provider.
final authTokenProvider = StateProvider<String?>((ref) => null);

// ── Auth interceptor ──────────────────────────────────────────────────────────

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authTokenProvider);

    if (token != null && !options.headers.containsKey('skip_auth')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept']       = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Clear token from memory and persistent storage on 401
      _ref.read(authTokenProvider.notifier).state = null;
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('auth_token');
        prefs.remove('current_user');
      });
    }
    super.onError(err, handler);
  }
}

// ── Safe log interceptor ─────────────────────────────────────────────────────

/// Logs requests and responses but truncates large bodies and skips HTML.
class SafeLogInterceptor extends Interceptor {
  static const _maxLogLength = 500;

  String _truncate(dynamic data) {
    final str = data?.toString() ?? '';
    if (str.length > _maxLogLength) {
      return '${str.substring(0, _maxLogLength)}... (${str.length} chars)';
    }
    return str;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('DioLog --> ${options.method} ${options.uri}');
      if (options.data != null) {
        // ignore: avoid_print
        print('DioLog     body: ${_truncate(options.data)}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final isJson = response.headers.value('content-type')?.contains('json') ?? false;
      if (isJson) {
        // ignore: avoid_print
        print('DioLog <-- ${response.statusCode} ${response.requestOptions.uri}');
        // ignore: avoid_print
        print('DioLog     ${_truncate(response.data)}');
      } else {
        // ignore: avoid_print
        print('DioLog <-- ${response.statusCode} ${response.requestOptions.uri} (non-JSON response, ${response.data?.toString().length ?? 0} bytes)');
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final status = err.response?.statusCode ?? 'N/A';
      final isJson = err.response?.headers.value('content-type')?.contains('json') ?? false;
      // ignore: avoid_print
      print('DioLog ERR $status ${err.requestOptions.method} ${err.requestOptions.uri}');
      if (isJson) {
        // ignore: avoid_print
        print('DioLog     ${_truncate(err.response?.data)}');
      } else {
        // ignore: avoid_print
        print('DioLog     ${err.message} (non-JSON error response)');
      }
    }
    handler.next(err);
  }
}

// ── Dio provider ──────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    SafeLogInterceptor(),
  ]);

  return dio;
});
