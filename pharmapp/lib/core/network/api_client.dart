import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Base URL ─────────────────────────────────────────────────────────────────

/// Resolves the backend base URL for the current platform.
/// Android emulator uses 10.0.2.2 to reach host localhost.
/// Web and desktop (Windows/Linux/macOS) use localhost directly.
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
      // Clear token on 401 — router will redirect to login via auth refresh
      _ref.read(authTokenProvider.notifier).state = null;
    }
    super.onError(err, handler);
  }
}

// ── Dio provider ──────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      // ignore: avoid_print
      logPrint: (obj) => print('DioLog: $obj'),
    ),
  ]);

  return dio;
});
