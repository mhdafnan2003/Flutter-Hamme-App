import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> storeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    debugPrint(
      '[SecureStorage] token save start, key=$_accessTokenKey len=${accessToken.length}',
    );
    await _storage.write(key: _accessTokenKey, value: accessToken);
    debugPrint('[SecureStorage] token save success: access_token saved');
    debugPrint('[SecureStorage] saved token length=${accessToken.length}');

    if (refreshToken != null && refreshToken.isNotEmpty) {
      debugPrint(
        '[SecureStorage] write refresh key=$_refreshTokenKey len=${refreshToken.length}',
      );
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } else {
      debugPrint('[SecureStorage] delete refresh key=$_refreshTokenKey');
      await _storage.delete(key: _refreshTokenKey);
    }
  }

  Future<String?> readAccessToken() async {
    final value = await _storage.read(key: _accessTokenKey);
    debugPrint(
      '[SecureStorage] read access key=$_accessTokenKey len=${value?.length ?? 0}',
    );
    if (value != null && value.isNotEmpty) {
      debugPrint('[SecureStorage] token read success: access_token length=${value.length}');
    } else {
      debugPrint('[SecureStorage] token read failed: no access token found');
    }
    return value;
  }

  Future<String?> readRefreshToken() async {
    final value = await _storage.read(key: _refreshTokenKey);
    debugPrint(
      '[SecureStorage] read refresh key=$_refreshTokenKey len=${value?.length ?? 0}',
    );
    return value;
  }

  Future<void> clearTokens() async {
    debugPrint('[SecureStorage] clear tokens');
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
