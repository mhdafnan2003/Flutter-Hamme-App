import '../../../../models/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
    required String instagramId,
    String? avatarUrl,
  });

  Future<AuthSession> guestRegister({
    required int age,
    required String displayName,
    required String username,
    String? instagramId,
    String? snapchatId,
    String? avatarUrl,
    String? deviceId,
    int? acceptedTermsVersion,
  });

  Future<AuthSession?> restoreSession();

  /// Restores a saved session only when the associated account is Pro.
  /// Used after the user explicitly restores their Pro purchase.
  Future<AuthSession?> restoreProSession();

  Future<void> logout();
}
