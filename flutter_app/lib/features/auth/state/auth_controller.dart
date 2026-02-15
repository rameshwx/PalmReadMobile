import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_expiry.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../domain/auth_models.dart';

class AuthState {
  const AuthState({this.user, this.token});

  final AuthUser? user;
  final String? token;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({AuthUser? user, String? token, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: token ?? this.token,
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final tokenStore = ref.read(secureTokenStoreProvider);
    final sessionExpired = ref.read(sessionExpiredProvider.notifier);
    final token = await tokenStore.readToken();

    if (token == null || token.isEmpty) {
      sessionExpired.state = false;
      return const AuthState();
    }

    try {
      final user = await ref.read(authApiProvider).me();
      sessionExpired.state = false;
      return AuthState(user: user, token: token);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await tokenStore.clearToken();
        sessionExpired.state = true;
        return const AuthState();
      }

      return AuthState(token: token);
    } catch (_) {
      // Preserve token on transient errors (e.g. temporary network issues).
      // Invalid tokens are handled via explicit 401 flows.
      return AuthState(token: token);
    }
  }

  Future<({OtpChallenge? challenge, String? error})> requestOtp(
      String email) async {
    try {
      final challenge =
          await ref.read(authApiProvider).requestOtp(email: email);
      return (challenge: challenge, error: null);
    } catch (error) {
      return (challenge: null, error: _errorMessage(error));
    }
  }

  Future<String?> verifyOtp({
    required String email,
    required String challengeId,
    required String code,
  }) async {
    final fallback = state.valueOrNull ?? const AuthState();

    try {
      final session = await ref.read(authApiProvider).verifyOtp(
            email: email,
            challengeId: challengeId,
            code: code,
          );
      await ref.read(secureTokenStoreProvider).writeToken(session.token);
      ref.read(sessionExpiredProvider.notifier).state = false;
      state = AsyncData(AuthState(user: session.user, token: session.token));
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(fallback);
      return _errorMessage(error);
    }
  }

  Future<String?> login(String email, String password) async {
    final fallback = state.valueOrNull ?? const AuthState();

    try {
      final session = await ref
          .read(authApiProvider)
          .login(email: email, password: password);
      await ref.read(secureTokenStoreProvider).writeToken(session.token);
      ref.read(sessionExpiredProvider.notifier).state = false;
      state = AsyncData(AuthState(user: session.user, token: session.token));
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(fallback);
      return _errorMessage(error);
    }
  }

  Future<String?> register(String name, String email, String password) async {
    final fallback = state.valueOrNull ?? const AuthState();

    try {
      final session = await ref
          .read(authApiProvider)
          .register(name: name, email: email, password: password);
      await ref.read(secureTokenStoreProvider).writeToken(session.token);
      ref.read(sessionExpiredProvider.notifier).state = false;
      state = AsyncData(AuthState(user: session.user, token: session.token));
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(fallback);
      return _errorMessage(error);
    }
  }

  Future<void> logout() async {
    await ref.read(secureTokenStoreProvider).clearToken();
    ref.read(sessionExpiredProvider.notifier).state = false;
    state = const AsyncData(AuthState());
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final message = payload['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    }

    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Unexpected authentication error.';
    }

    return text;
  }
}
