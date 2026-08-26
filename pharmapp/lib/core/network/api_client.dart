import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/services/auth_storage.dart';
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

/// Incremented whenever a 403 is received while authenticated.
/// SubscriptionNotifier watches this to trigger an immediate refresh so that
/// org suspension is reflected without waiting for the next app resume.
final orgAccessRevokedProvider = StateProvider<int>((ref) => 0);

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
    if (err.response?.statusCode == 403) {
      // 403 while authenticated = org suspended or access revoked by superuser.
      // Signal SubscriptionNotifier to refresh so the router guard fires.
      final sentAuth = err.requestOptions.headers.containsKey('Authorization');
      if (sentAuth) {
        _ref.read(orgAccessRevokedProvider.notifier).update((n) => n + 1);
      }
    }
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
        AuthStorage.delete('auth_token').ignore();
        AuthStorage.delete('current_user').ignore();
      }
    }
    super.onError(err, handler);
  }
}

// ── Error normalizer interceptor ──────────────────────────────────────────────

/// Normalises DRF error bodies so every downstream `data?['detail']` is safe.
///
/// Handles four shapes:
///   • `["msg"]`              → `{"detail": "msg"}`
///   • `{"field": ["msg"]}`   → adds `"detail": "field: msg"` (field-level errors)
///   • `{"detail": "msg"}`    → untouched
///   • `"plain text"`         → `{"detail": "plain text"}`
///
/// Without this, indexing a Dart String with the String "detail" throws
/// `Invalid argument (index): "detail"` on web (dart2js type-checks the index).
class ErrorNormalizerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final resp = err.response;
    if (resp != null) {
      final data = resp.data;
      if (data is List) {
        // Top-level list: ["error"] → {"detail": "error"}
        final message = data.isNotEmpty ? data.first.toString() : 'Request failed';
        resp.data = <String, dynamic>{'detail': message};
      } else if (data is String) {
        // Plain-text or HTML response (e.g. Django 500 page, nginx 403, CSRF error).
        // Never expose raw HTML to the user — replace with a clean message.
        final String message;
        if (data.trimLeft().startsWith('<') || data.contains('<!doctype') || data.contains('<html')) {
          final code = resp.statusCode ?? 0;
          message = 'Server error ($code) — please try again or contact support.';
        } else {
          message = data.isNotEmpty ? data : 'Request failed';
        }
        resp.data = <String, dynamic>{'detail': message};
      } else if (data is Map && !data.containsKey('detail')) {
        // Field-level DRF validation errors: {"field": ["msg"]} → inject detail
        for (final entry in data.entries) {
          final val = entry.value;
          String? msg;
          if (val is List && val.isNotEmpty) {
            msg = val.first.toString();
          } else if (val is String && val.isNotEmpty) {
            msg = val;
          }
          if (msg != null) {
            final prefix = entry.key == 'non_field_errors' ? '' : '${entry.key}: ';
            (resp.data as Map<String, dynamic>)['detail'] = '$prefix$msg';
            break;
          }
        }
      }
    }
    handler.next(err);
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

// ── Retry interceptor (poor connections) ─────────────────────────────────────

/// Number of requests currently waiting on a retry. `> 0` means the network is
/// reachable but struggling — the shell shows a "slow connection" banner.
final slowNetworkProvider = StateProvider<int>((ref) => 0);

/// `true` once a request has exhausted its retries with a connection-level
/// failure — the device claims to be online but the link is unusable.
///
/// Cleared by the next successful response. Callers that have an offline path
/// (POS checkout, queued mutations) use this to skip a doomed network call
/// instead of making the user wait out the timeouts.
final networkDegradedProvider = StateProvider<bool>((ref) => false);

/// Retries transient network failures instead of surfacing them to the user.
///
/// Poor connections (2G/3G, congested wifi, a sleeping PythonAnywhere dyno)
/// fail with a timeout or a dropped socket, not an HTTP error — one retry with
/// a short backoff usually succeeds.
///
/// Only replays requests that are safe to repeat: GET/HEAD, or a request the
/// caller marked with `extra['idempotent'] = true` / an `Idempotency-Key`
/// header. Writes without a key are never retried — the first attempt may have
/// reached the server even though the response was lost.
class RetryInterceptor extends Interceptor {
  final Ref _ref;
  final Dio _dio;

  RetryInterceptor(this._ref, this._dio);

  static const _delays = [Duration(seconds: 1), Duration(seconds: 3)];

  bool _isTransient(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        // Gateway-level failures from a cold/overloaded backend.
        final code = err.response?.statusCode ?? 0;
        return code == 502 || code == 503 || code == 504;
    }
  }

  bool _isSafeToReplay(RequestOptions o) {
    final method = o.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD') return true;
    if (o.extra['idempotent'] == true) return true;
    return o.headers.containsKey('Idempotency-Key');
  }

  /// Final outcome of a transient failure.
  ///
  /// Marks the network degraded, and rewrites a gateway error (502/503/504 from
  /// a sleeping or overloaded backend) into a connection-level [DioException]
  /// with no response — every offline fallback in the app keys off
  /// `e.response == null`, so this is what makes them fire for a dead backend
  /// as well as a dead link.
  DioException _giveUp(DioException err) {
    if (!_isTransient(err)) return err;
    _ref.read(networkDegradedProvider.notifier).state = true;
    if (err.response == null) return err;
    return DioException(
      requestOptions: err.requestOptions,
      type: DioExceptionType.connectionError,
      error: err.error ?? 'HTTP ${err.response?.statusCode}',
      message: 'Backend unreachable (${err.response?.statusCode})',
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // A response of any kind means the link is usable again.
    if (_ref.read(networkDegradedProvider)) {
      _ref.read(networkDegradedProvider.notifier).state = false;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra['retry_attempt'] as int?) ?? 0;

    if (attempt >= _delays.length ||
        !_isTransient(err) ||
        !_isSafeToReplay(options) ||
        options.extra['noRetry'] == true) {
      return handler.next(_giveUp(err));
    }

    options.extra['retry_attempt'] = attempt + 1;
    _ref.read(slowNetworkProvider.notifier).update((n) => n + 1);
    try {
      await Future<void>.delayed(_delays[attempt]);
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(_giveUp(e));
    } catch (_) {
      handler.next(_giveUp(err));
    } finally {
      _ref.read(slowNetworkProvider.notifier).update((n) => n > 0 ? n - 1 : 0);
    }
  }
}

/// Aborts a write before it is sent when [networkDegradedProvider] is set.
///
/// Throws the same connection-level [DioException] the transport would have
/// thrown, so the caller's existing `e.response == null` branch queues the
/// write immediately instead of making the user sit through the timeouts.
/// Only for writes that have an offline path — a write that must reach the
/// server should be left to attempt the request.
void abortIfNetworkDegraded(Ref ref, String path, {String method = 'POST'}) {
  if (!ref.read(networkDegradedProvider)) return;
  throw DioException(
    requestOptions: RequestOptions(path: path, method: method),
    type: DioExceptionType.connectionError,
    message: 'Connection is down — queued without attempting the request',
  );
}

// ── Idempotency ───────────────────────────────────────────────────────────────

const _kClientInstallIdKey = 'client_install_id';
String? _cachedClientInstallId;

/// Random id generated once per install and kept in SharedPreferences.
///
/// Queue ids are microsecond timestamps, so two devices can produce the same
/// one. Prefixing with this makes an `Idempotency-Key` unique across the whole
/// backend, which is what lets the server dedupe by key alone.
Future<String> clientInstallId() async {
  if (_cachedClientInstallId != null) return _cachedClientInstallId!;
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kClientInstallIdKey);
  if (id == null || id.isEmpty) {
    final rnd = Random.secure();
    id = List.generate(
        8, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_kClientInstallIdKey, id);
  }
  _cachedClientInstallId = id;
  return id;
}

/// Header that tells the backend to apply this write at most once, however
/// many times it is replayed. [localId] must be stable across replays of the
/// same logical write — use the queue entry's id.
Future<Map<String, String>> idempotencyHeader(String localId) async =>
    {'Idempotency-Key': '${await clientInstallId()}:$localId'};

// ── Dio provider ──────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      // Generous enough for a 2G/3G link or a cold backend; RetryInterceptor
      // replays anything that still times out.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    RetryInterceptor(ref, dio),
    ErrorNormalizerInterceptor(),
    SafeLogInterceptor(),
  ]);

  return dio;
});
