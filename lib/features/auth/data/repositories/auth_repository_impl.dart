import '../../../../core/services/secure_storage_service.dart';
import '../../../../models/auth_session.dart';
import '../datasources/auth_remote_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorageService,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorageService = secureStorageService;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorageService;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _remoteDataSource.login(
      email: email,
      password: password,
    );
    await _persistSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } finally {
      await _secureStorageService.clearTokens();
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final accessToken = await _secureStorageService.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    try {
      final refreshToken = await _secureStorageService.readRefreshToken();
      final user = await _remoteDataSource.getCurrentUser();
      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } catch (_) {
      await _secureStorageService.clearTokens();
      return null;
    }
  }

  @override
  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
    required String instagramId,
    String? profileImageUrl,
  }) async {
    final session = await _remoteDataSource.signUp(
      name: name,
      email: email,
      password: password,
      instagramId: instagramId,
      profileImageUrl: profileImageUrl,
    );
    await _persistSession(session);
    return session;
  }

  @override
  Future<AuthSession> guestRegister({
    required int age,
    required String displayName,
    required String username,
    String? instagramId,
    String? snapchatId,
    String? avatarUrl,
    String? deviceId,
  }) async {
    debugPrint('[AuthRepo] guestRegister remote call start');
    final session = await _remoteDataSource.guestRegister(
      age: age,
      displayName: displayName,
      username: username,
      instagramId: instagramId,
      snapchatId: snapchatId,
      avatarUrl: avatarUrl,
      deviceId: deviceId,
    );
    debugPrint('[AuthRepo] guestRegister remote call success user=${session.user.id}');
    debugPrint('[AuthRepo] token persist start');
    await _persistSession(session);
    debugPrint('[AuthRepo] token persist success');
    return session;
  }

  Future<void> _persistSession(AuthSession session) {
    return _secureStorageService.storeTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }
}
