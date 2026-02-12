import 'package:dio/dio.dart';

import '../utils/correlation_id.dart';

typedef TokenGetter = Future<String?> Function();
typedef TokenClearer = Future<void> Function();
typedef SessionExpiredHandler = Future<void> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenGetter tokenGetter,
    required TokenClearer tokenClearer,
    required SessionExpiredHandler onSessionExpired,
  })  : _tokenGetter = tokenGetter,
        _tokenClearer = tokenClearer,
        _onSessionExpired = onSessionExpired;

  final TokenGetter _tokenGetter;
  final TokenClearer _tokenClearer;
  final SessionExpiredHandler _onSessionExpired;
  bool _isHandlingUnauthorized = false;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenGetter();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    options.headers['X-Correlation-Id'] ??= CorrelationId.next();
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isHandlingUnauthorized) {
      _isHandlingUnauthorized = true;
      try {
        await _tokenClearer();
        await _onSessionExpired();
      } finally {
        _isHandlingUnauthorized = false;
      }
    }

    super.onError(err, handler);
  }
}
