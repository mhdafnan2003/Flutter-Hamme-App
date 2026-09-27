import 'dart:async';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

import '../../../../core/services/secure_storage_service.dart';
import '../../../../models/auth_session.dart';
import '../datasources/auth_remote_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/app_exception.dart';

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
      // Revoke only this device's session.
      final refreshToken = await _secureStorageService.readRefreshToken();
      await _remoteDataSource.logout(refreshToken: refreshToken);
    } finally {
      await _secureStorageService.clearTokens();
    }
  }

  /// Returns null when there is no saved session or the backend rejected it.
  /// Rethrows a transient failure (offline, timeout, rate limit, server
  /// error) with the tokens kept: the saved session may be perfectly valid,
  /// and treating the user as signed out would send them to onboarding.
  @override
  Future<AuthSession?> restoreSession() async {
    try {
      final accessToken = await _secureStorageService.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[AuthRepo] restoreSession: no access token');
        return null;
      }

      final refreshToken = await _secureStorageService.readRefreshToken();
      final user = await _remoteDataSource.getCurrentUser();
      debugPrint('[AuthRepo] restoreSession success: user=${user.id}');
      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } catch (error) {
      if (_isTransientFailure(error)) {
        debugPrint('[AuthRepo] restoreSession: transient error: $error');
        rethrow;
      }
      if (error is AppException && (error.statusCode == 401 || error.statusCode == 403)) {
        debugPrint('[AuthRepo] restoreSession: auth invalid, clearing tokens');
        await _secureStorageService.clearTokens();
      } else {
        debugPrint('[AuthRepo] restoreSession: failed: $error');
      }
      return null;
    }
  }

  /// Network trouble or a server-side error, as opposed to the backend
  /// rejecting the session.
  static bool _isTransientFailure(Object error) {
    if (error is AppException) {
      final status = error.statusCode;
      return status != null &&
          (status == 408 || status == 429 || status >= 500);
    }
    return error is IOException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  @override
  Future<AuthSession?> restoreProSession() async {
    try {
      final accessToken = await _secureStorageService.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[AuthRepo] restoreProSession: no saved session');
        return null;
      }

      final refreshToken = await _secureStorageService.readRefreshToken();
      final user = await _remoteDataSource.getCurrentUser();
      if (!user.isPro) {
        debugPrint('[AuthRepo] restoreProSession: saved user is not Pro');
        return null;
      }

      debugPrint('[AuthRepo] restoreProSession success: user=${user.id}');
      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } catch (error) {
      debugPrint('[AuthRepo] restoreProSession failed: $error');
      return null;
    }
  }

  @override
  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
    required String instagramId,
    String? avatarUrl,
  }) async {
    final session = await _remoteDataSource.signUp(
      name: name,
      email: email,
      password: password,
      instagramId: instagramId,
      avatarUrl: avatarUrl,
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
    int? acceptedTermsVersion,
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
      acceptedTermsVersion: acceptedTermsVersion,
    );
    debugPrint('[AuthRepo] guestRegister remote call success user=${session.user.id}');
    debugPrint('[AuthRepo] token persist start');
    await _persistSession(session);
    debugPrint('[AuthRepo] token persist success');
    return session;
  }

  Future<void> _persistSession(AuthSession session) {
    debugPrint(
      '[AuthRepo] persistSession access=${session.accessToken.length} refresh=${session.refreshToken?.length ?? 0}',
    );
    return _secureStorageService.storeTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }
}
