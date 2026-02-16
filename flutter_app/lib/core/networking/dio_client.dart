import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../session/session_expiry.dart';
import '../storage/secure_token_store.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  final sessionExpired = ref.read(sessionExpiredProvider.notifier);
  final apiPathPrefix = _normalizePathPrefix(AppConfig.apiBasePath);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConfig.uploadTimeoutSeconds),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: Duration(seconds: AppConfig.uploadTimeoutSeconds),
      headers: {'Accept': 'application/json'},
    ),
  );

  if (apiPathPrefix.isNotEmpty) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          final isAbsolute = path.startsWith('http://') ||
              path.startsWith('https://') ||
              path.startsWith('ws://') ||
              path.startsWith('wss://');

          if (isAbsolute || path.startsWith(apiPathPrefix)) {
            handler.next(options);
            return;
          }

          if (path.startsWith('/')) {
            options.path = '$apiPathPrefix$path';
          } else {
            options.path = '$apiPathPrefix/$path';
          }

          handler.next(options);
        },
      ),
    );
  }

  dio.interceptors.add(
    AuthInterceptor(
      tokenGetter: tokenStore.readToken,
      tokenClearer: tokenStore.clearToken,
      onSessionExpired: () async {
        if (!sessionExpired.state) {
          sessionExpired.state = true;
        }
      },
    ),
  );

  return dio;
});

String _normalizePathPrefix(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '/') {
    return '';
  }

  final withLeading = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  if (withLeading.endsWith('/')) {
    return withLeading.substring(0, withLeading.length - 1);
  }
  return withLeading;
}
