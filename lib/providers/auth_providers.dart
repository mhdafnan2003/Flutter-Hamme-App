import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_use_case.dart';
import '../features/auth/domain/usecases/sign_up_use_case.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../models/auth_session.dart';
import 'api_providers.dart';
import 'deferred_interaction_provider.dart';
import 'onboarding_providers.dart';
import 'push_notification_providers.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiServiceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

enum AuthStatus { loading, authenticated, unauthenticated }

final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading) return AuthStatus.loading;
  return authState.value == null
      ? AuthStatus.unauthenticated
      : AuthStatus.authenticated;
});

class AuthController extends AsyncNotifier<AuthSession?> {
  static const _installationInitializedKey = 'installation_initialized_v1';
  static const _onboardingCompleteKey = 'onboarding_complete';

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() async {
    final preferences = await SharedPreferences.getInstance();
    final isFirstLaunchOfInstallation =
        !(preferences.getBool(_installationInitializedKey) ?? false);
    if (isFirstLaunchOfInstallation) {
      await preferences.setBool(_installationInitializedKey, true);

      // Existing installations already have onboarding state. A new iOS
      // install can still have an old Keychain token, but it must not restore
      // a profile automatically; only the Pro Restore action may use it.
      // Android secure storage follows the app installation lifecycle, so it
      // should always attempt to restore a valid saved session.
      final isExistingInstallation = preferences.containsKey(
        _onboardingCompleteKey,
      );
      final shouldProtectFreshIosInstall =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      if (!isExistingInstallation && shouldProtectFreshIosInstall) {
        debugPrint(
          '[Auth] fresh installation: automatic session restore skipped',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        return null;
      }
    }

    // Add a minimum delay of 2 seconds to ensure the splash screen is visible
    final results = await Future.wait([
      _repository.restoreSession(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    final restored = results[0] as AuthSession?;
    debugPrint(
      '[Auth] restoreSession complete: hasSession=${restored != null}, '
      'user=${restored?.user.id}',
    );
    if (restored != null) {
      await _markOnboardingComplete();
      await _registerPushToken();
    }
    return restored;
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final session = await ref.read(loginUseCaseProvider)(
        email: email,
        password: password,
      );
      await _markOnboardingComplete();
      await _registerPushToken();
      state = AsyncData(session);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await _unregisterPushToken();
    await _repository.logout();
    await _clearLocalSession();
  }

  /// Deletes the remote profile before clearing every locally stored trace of
  /// the session. This must not call logout afterward: the account no longer
  /// exists once deletion has succeeded.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      await _unregisterPushToken();
      await ProfileRemoteDataSource(ref.read(apiServiceProvider)).deleteMe();
      await ref.read(secureStorageServiceProvider).clearTokens();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('pro_entitlement', false);
      await _clearLocalSession();
    } catch (_) {
      // Preserve the authenticated state if deletion did not complete so the
      // user can retry rather than being incorrectly told it was deleted.
      state = AsyncData(await _repository.restoreSession());
      rethrow;
    }
  }

  Future<void> _clearLocalSession() async {
    await ref.read(onboardingDraftProvider.notifier).clear();
    ref.read(onboardingProfileImageProvider.notifier).state = null;
    await ref.read(onboardingCompletionProvider.notifier).reset();
    await ref.read(shareTutorialCompletionProvider.notifier).reset();
    ref.read(deferredInteractionTokenProvider.notifier).state = null;
    ref.read(deferredShareCodeProvider.notifier).state = null;
    ref.read(deferredInteractionTypeProvider.notifier).state = null;
    state = const AsyncData(null);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String instagramId,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading();
    try {
      final session = await ref.read(signUpUseCaseProvider)(
        name: name,
        email: email,
        password: password,
        instagramId: instagramId,
        avatarUrl: avatarUrl,
      );
      await _markOnboardingComplete();
      await _registerPushToken();
      state = AsyncData(session);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refreshUser() async {
    final current = state.value;
    if (current == null) return;
    try {
      final user =
          await ref.read(authRemoteDataSourceProvider).getCurrentUser();
      state = AsyncData(current.copyWith(user: user));
    } catch (e) {
      debugPrint('[Auth] refreshUser failed: $e');
    }
  }

  /// Called only after the user has explicitly restored a Pro store purchase.
  /// A saved Keychain session is accepted only when its server profile is Pro.
  Future<bool> restoreProProfile() async {
    final session = await _repository.restoreProSession();
    if (session == null) return false;
    await _markOnboardingComplete();
    await _registerPushToken();
    state = AsyncData(session);
    return true;
  }

  /// Accepts a session recovered by the backend from a Google-verified active
  /// subscription. This is used after reinstall, when local auth storage may
  /// have been removed but Play still owns the subscription.
  Future<void> acceptBillingRestoredSession(AuthSession session) async {
    await ref
        .read(secureStorageServiceProvider)
        .storeTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
    await _markOnboardingComplete();
    await _registerPushToken();
    state = AsyncData(session);
  }

  Future<void> guestRegister({
    required int age,
    required String displayName,
    required String username,
    String? instagramId,
    String? snapchatId,
    String? avatarUrl,
    String? deviceId,
  }) async {
    debugPrint(
      '[Auth] guestRegister start: username=$username, displayName=$displayName, '
      'deviceId=$deviceId',
    );
    state = const AsyncLoading();
    try {
      final session = await _repository.guestRegister(
        age: age,
        displayName: displayName,
        username: username,
        instagramId: instagramId,
        snapchatId: snapchatId,
        avatarUrl: avatarUrl,
        deviceId: deviceId,
      );
      debugPrint('[Auth] guestRegister success: token received and saved');
      await _registerPushToken();
      state = AsyncData(session);
    } catch (e, st) {
      debugPrint('[Auth] guestRegister failed: $e');
      debugPrint('[Auth] guestRegister stacktrace: $st');
      state = AsyncError(e, st);
    }
  }

  Future<void> _markOnboardingComplete() {
    return ref.read(onboardingCompletionProvider.notifier).markComplete();
  }

  Future<void> _registerPushToken() {
    return ref.read(pushNotificationServiceProvider).registerToken();
  }

  Future<void> _unregisterPushToken() {
    return ref.read(pushNotificationServiceProvider).unregisterToken();
  }
}
