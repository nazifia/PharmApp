import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Base URL ─────────────────────────────────────────────────────────────────

/// Resolves the backend base URL.
/// - Debug: localhost (web/desktop) or 10.0.2.2 (Android emulator)
/// - Release: https://PharmApp.pythonanywhere.com/api
/// Override at build time via --dart-define=API_URL=... (takes priority always).
/// Override at runtime via SharedPreferences key 'api_base_url' (see main.dart).
final baseUrlProvider = StateProvider<String>((ref) {
  // ignore: do_not_use_environment
  const env = String.fromEnvironment('API_URL', defaultValue: '');
  if (env.isNotEmpty) return env;

  if (kDebugMode) {
    if (!kIsWeb) return 'http://10.0.2.2:8000/api'; // Android emulator
    return 'http://localhost:8000/api';
  }

  return 'https://PharmApp.pythonanywhere.com/api';
});

/// Derived from [baseUrlProvider] — same origin without `/api` suffix.
/// Used to resolve media URLs like `/media/org_logos/avatar.png`.
final mediaBaseUrlProvider = StateProvider<String>((ref) {
  final base = ref.watch(baseUrlProvider);
  return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
});

/// Resolves a relative media path (e.g. '/media/org_logos/x.png')
/// or raw filename (e.g. 'org_logos/x.png') to a full URL.
/// Returns the input unchanged if it already starts with 'http'.
String resolvedMediaUrl(String path, {String? mediaBase}) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  mediaBase ??= 'https://PharmApp.pythonanywhere.com'; // safe default; overridden in practice
  final cleanPath = path.startsWith('/') ? path : '/$path';
  return '$mediaBase$cleanPath';
}

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

    final skipAuth = options.headers.remove('skip_auth');
    if (token != null && skipAuth == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept']       = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Only invalidate the session if we actually sent a Bearer token.
      // If the token was null when the request fired, this 401 is a
      // start-up race condition — do not wipe a valid token that may
      // have been restored by checkAuthStatus() in the meantime.
      //
      // Also skip clearing when the caller sets extra['skipTokenClear'] = true
      // (used by background profile-refresh calls that should never log the
      // user out if the endpoint is absent or transiently unavailable).
      final sentAuth = err.requestOptions.headers.containsKey('Authorization');
      final skipClear = err.requestOptions.extra['skipTokenClear'] == true;
      if (sentAuth && !skipClear) {
        _ref.read(authTokenProvider.notifier).state = null;
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('auth_token');
          prefs.remove('current_user');
        });
      }
    }
    super.onError(err, handler);
  }
}

// ── Safe log interceptor ─────────────────────────────────────────────────────

/// Logs requests and responses (method + URI + status only — never body/headers
/// that may contain tokens, passwords, or PII).
class SafeLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('DioLog --> ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('DioLog <-- ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final statusCode = err.response?.statusCode ?? 'N/A';
      // ignore: avoid_print
      print('DioLog ERR $statusCode ${err.requestOptions.method} ${err.requestOptions.uri}');
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
