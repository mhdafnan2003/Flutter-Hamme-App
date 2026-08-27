import '../../../../core/services/api_service.dart';
import '../../../../models/app_user.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<AppUser> getMe() async {
    final response =
        await _apiService.get('/profiles/me', authenticated: true)
            as Map<String, dynamic>;
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<AppUser> getPublicProfile(String shareCode) async {
    final response =
        await _apiService.get('/profiles/public/$shareCode')
            as Map<String, dynamic>;
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updateMe({
    String? name,
    String? instagramId,
    String? snapchatId,
    String? username,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (instagramId != null && instagramId.isNotEmpty) {
      body['instagramId'] = instagramId;
    }
    if (snapchatId != null && snapchatId.isNotEmpty) {
      body['snapchatId'] = snapchatId;
    }
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      body['avatarUrl'] = avatarUrl;
    }

    final response =
        await _apiService.patch('/profiles/me', body: body, authenticated: true)
            as Map<String, dynamic>;
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Permanently deletes the signed-in user's Hamme profile and its data.
  Future<void> deleteMe() async {
    await _apiService.delete('/profiles/me', authenticated: true);
  }

  /// Registers (or refreshes) this device's push token for the signed-in user.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _apiService.put(
      '/profiles/device-token',
      body: {'token': token, 'platform': platform},
      authenticated: true,
    );
  }

  /// Removes a push token, e.g. on logout, so a signed-out device stops
  /// receiving another account's notifications.
  Future<void> unregisterDeviceToken(String token) async {
    await _apiService.delete(
      '/profiles/device-token',
      body: {'token': token},
      authenticated: true,
    );
  }
}
