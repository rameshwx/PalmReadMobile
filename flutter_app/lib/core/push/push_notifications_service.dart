import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/push_token_store.dart';
import 'push_bootstrap.dart';
import 'push_tokens_api.dart';

final pushNotificationsServiceProvider = Provider<PushNotificationsService>(
  (ref) {
    final service = PushNotificationsService(
      messaging: FirebaseMessaging.instance,
      api: ref.watch(pushTokensApiProvider),
      tokenStore: ref.watch(pushTokenStoreProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

class PushNotificationsService {
  PushNotificationsService({
    required FirebaseMessaging messaging,
    required PushTokensApi api,
    required PushTokenStore tokenStore,
  })  : _messaging = messaging,
        _api = api,
        _tokenStore = tokenStore;

  final FirebaseMessaging _messaging;
  final PushTokensApi _api;
  final PushTokenStore _tokenStore;

  bool _started = false;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> start() async {
    if (!PushBootstrap.isInitialized) {
      await PushBootstrap.initialize();
      if (!PushBootstrap.isInitialized) {
        return;
      }
    }

    if (_started) {
      await syncToken();
      return;
    }
    _started = true;

    await _requestPermissionIfNeeded();
    await syncToken();

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      await _registerToken(token);
    });
  }

  Future<void> syncToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }
      await _registerToken(token.trim());
    } catch (error) {
      debugPrint('Push token sync failed: $error');
    }
  }

  Future<void> unregisterForLogout() async {
    try {
      final stored = await _tokenStore.read();
      final fallback = stored == null ? await _messaging.getToken() : null;
      final token = (stored ?? fallback)?.trim();
      if (token == null || token.isEmpty) {
        await _tokenStore.clear();
        return;
      }

      try {
        await _api.unregister(token: token);
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (status != 401 && status != 403) {
          rethrow;
        }
      }
      await _tokenStore.clear();
    } catch (error) {
      debugPrint('Push token unregister skipped: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    final previous = await _tokenStore.read();
    if (previous != null && previous.trim() == token) {
      return;
    }

    try {
      await _api.register(
        token: token,
        platform: _platformName(),
      );
      await _tokenStore.write(token);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _requestPermissionIfNeeded() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('Push permission: ${settings.authorizationStatus}');
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}
