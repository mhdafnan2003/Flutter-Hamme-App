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
    String? username,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (instagramId != null && instagramId.isNotEmpty) {
      body['instagramId'] = instagramId;
    }
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      body['avatarUrl'] = avatarUrl;
    }

    final response =
        await _apiService.patch(
              '/profiles/me',
              body: body,
              authenticated: true,
            )
            as Map<String, dynamic>;
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }
}
