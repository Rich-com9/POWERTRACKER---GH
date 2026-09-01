import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(
      key: accessTokenKey,
      value: accessToken,
    );

    if (refreshToken != null) {
      await _storage.write(
        key: refreshTokenKey,
        value: refreshToken,
      );
    }
  }

  Future<String?> getAccessToken() async {
    return _storage.read(
      key: accessTokenKey,
    );
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(
      key: refreshTokenKey,
    );
  }

  Future<void> clearTokens() async {
    await _storage.delete(
      key: accessTokenKey,
    );

    await _storage.delete(
      key: refreshTokenKey,
    );
  }
}