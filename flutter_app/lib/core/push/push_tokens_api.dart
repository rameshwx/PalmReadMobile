import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../networking/dio_client.dart';

final pushTokensApiProvider = Provider<PushTokensApi>((ref) {
  return PushTokensApi(ref.watch(dioProvider));
});

class PushTokensApi {
  PushTokensApi(this._dio);

  final Dio _dio;

  Future<void> register({
    required String token,
    required String platform,
    String? appVersion,
    String? deviceModel,
  }) async {
    await _dio.post<void>(
      '/api/push-tokens/register',
      data: {
        'token': token,
        'platform': platform,
        'app_version': appVersion,
        'device_model': deviceModel,
      },
    );
  }

  Future<void> unregister({required String token}) async {
    await _dio.post<void>(
      '/api/push-tokens/unregister',
      data: {'token': token},
    );
  }
}
