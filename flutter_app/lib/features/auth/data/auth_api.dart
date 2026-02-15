import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/dio_client.dart';
import '../domain/auth_models.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthApi(dio);
});

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<OtpChallenge> requestOtp({required String email}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/otp/request',
      data: {'email': email},
    );

    return OtpChallenge.fromJson(response.data ?? const {});
  }

  Future<AuthSession> verifyOtp({
    required String email,
    required String challengeId,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/otp/verify',
      data: {
        'email': email,
        'challenge_id': challengeId,
        'code': code,
      },
    );

    return AuthSession.fromJson(response.data!);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    return AuthSession.fromJson(response.data!);
  }

  Future<AuthSession> login(
      {required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return AuthSession.fromJson(response.data!);
  }

  Future<AuthUser> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/auth/me');
    final payload = response.data ?? const {};
    return AuthUser.fromJson(payload['user'] as Map<String, dynamic>);
  }

  Future<String> forgotPassword({required String email}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/forgot-password',
      data: {'email': email},
    );
    final payload = response.data ?? const {};
    return payload['message']?.toString() ??
        'If an account exists for this email, a reset link has been sent.';
  }
}
