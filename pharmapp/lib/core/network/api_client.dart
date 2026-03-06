import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provides the base URL depending on environment
final baseUrlProvider = Provider<String>((ref) {
  // TODO: Swap out with production URL when ready
  return 'http://10.0.2.2:8000/api'; 
});

// Provides the secure token (Can be mapped to Isar or flutter_secure_storage later)
class AuthTokenNotifier extends StateNotifier<String?> {
  AuthTokenNotifier() : super(null);

  void setToken(String token) => state = token;
  void clearToken() => state = null;
}

final authTokenProvider = StateNotifierProvider<AuthTokenNotifier, String?>((ref) {
  return AuthTokenNotifier();
});

// The Interceptor that attaches the Bearer token to every request
class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(authTokenProvider);
    
    // Attach token if it exists and wasn't explicitly skipped
    if (token != null && !options.headers.containsKey('skip_auth')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    // Add default headers expecting JSON
    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Automatically log out user if a 401 Unauthorized is caught universally
    if (err.response?.statusCode == 401) {
      ref.read(authTokenProvider.notifier).clearToken();
      // TODO: Trigger navigation back to login screen via GoRouter refresh listen
    }
    super.onError(err, handler);
  }
}

// The core Dio Client Provider injected into Repositories
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    // Logging interceptor for debugging network calls in development
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('DioLog: $obj'),
    ),
  ]);

  return dio;
});
