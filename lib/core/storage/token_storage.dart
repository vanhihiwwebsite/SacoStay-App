import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const tokenKey = 'saco_stay_token';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: tokenKey);

  Future<void> write(String token) => _storage.write(key: tokenKey, value: token);

  Future<void> delete() => _storage.delete(key: tokenKey);
}
