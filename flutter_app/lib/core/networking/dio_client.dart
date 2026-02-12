import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../session/session_expiry.dart';
import '../storage/secure_token_store.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  final sessionExpired = ref.read(sessionExpiredProvider.notifier);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConfig.uploadTimeoutSeconds),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: Duration(seconds: AppConfig.uploadTimeoutSeconds),
      headers: {'Accept': 'application/json'},
    ),
  );

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
