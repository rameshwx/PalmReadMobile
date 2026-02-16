import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final pushTokenStoreProvider = Provider<PushTokenStore>((ref) {
  return PushTokenStore(const FlutterSecureStorage());
});

class PushTokenStore {
  PushTokenStore(this._storage);

  static const _key = 'fcm_push_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}
