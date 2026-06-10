import '../../../../core/services/api_service.dart';
import '../../../../models/app_user.dart';
import '../../../../models/auth_session.dart';
import 'package:flutter/foundation.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response =
        await _apiService.post(
              '/auth/login',
              body: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    return AuthSession.fromJson(response);
  }

  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
    required String instagramId,
    String? avatarUrl,
  }) async {
    final response =
        await _apiService.post(
              '/auth/signup',
              body: {
                'name': name,
                'email': email,
                'password': password,
                'instagramId': instagramId,
                'avatarUrl': avatarUrl,
              },
            )
            as Map<String, dynamic>;

    return AuthSession.fromJson(response);
  }

  Future<AuthSession> guestRegister({
    required int age,
    required String displayName,
    required String username,
    String? instagramId,
    String? snapchatId,
    String? avatarUrl,
    String? deviceId,
  }) async {
    debugPrint('[AuthDS] guestRegister request begin');
    final response =
        await _apiService.post(
              '/auth/guest-register',
              body: {
                'age': age,
                'displayName': displayName,
                'username': username,
                'instagramId': instagramId,
                'snapchatId': snapchatId,
                'avatarUrl': avatarUrl,
                'deviceId': deviceId,
              },
            )
            as Map<String, dynamic>;
    debugPrint('[AuthDS] guestRegister response parsed successfully');
    debugPrint(
      '[AuthDS] response keys: ${response.keys.join(',')} '
      'hasAccessToken=${response['accessToken'] != null} '
      'hasRefreshToken=${response['refreshToken'] != null} '
      'hasUser=${response['user'] != null}',
    );
    final rawToken = response['accessToken'];
    debugPrint('[AuthDS] raw guestRegister response (partial): keys=${response.keys.join(',')}');
    debugPrint('[AuthDS] extracted token type: ${rawToken.runtimeType}');
    debugPrint('[AuthDS] token length: ${rawToken?.toString().length}');
    
    return AuthSession.fromJson(response);
  }

  Future<AppUser> getCurrentUser() async {
    debugPrint('[AuthDS] getCurrentUser start');
    final response =
        await _apiService.get('/auth/me', authenticated: true)
            as Map<String, dynamic>;

    debugPrint('[AuthDS] getCurrentUser success');
    return AppUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _apiService.post('/auth/logout', authenticated: true);
  }
}
