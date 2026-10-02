import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/community_rules.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/terms_acceptance_store.dart';
import '../core/utils/app_exception.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_use_case.dart';
import '../features/auth/domain/usecases/sign_up_use_case.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../models/app_user.dart';
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

final termsAcceptanceStoreProvider = Provider<TermsAcceptanceStore>((ref) {
  return TermsAcceptanceStore();
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

enum AuthStatus { loading, authenticated, unauthenticated }

final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading) return AuthStatus.loading;
  // The saved session could not be checked (offline, timeout, server error)
  // even after retries. Keep the user on the splash, which offers a retry:
  // sending them to onboarding would create a second guest account.
  if (authState.hasError && !authState.hasValue) return AuthStatus.loading;
  return authState.value == null
      ? AuthStatus.unauthenticated
      : AuthStatus.authenticated;
});

/// False only while a signed-in user still has to agree to the current Terms
/// of Use / Community Guidelines; the router then holds them on the terms gate.
final currentUserTermsAcceptedProvider = Provider<bool>((ref) {
  return ref.watch(
    authControllerProvider.select(
      (auth) => auth.valueOrNull?.user.hasAcceptedCurrentTerms ?? true,
    ),
  );
});

/// Whether the account-suspended notice must be shown. Set when the backend
/// reports a ban and kept across launches until the user acknowledges it.
final accountSuspendedProvider =
    AsyncNotifierProvider<AccountSuspendedNotifier, bool>(
      AccountSuspendedNotifier.new,
    );

class AccountSuspendedNotifier extends AsyncNotifier<bool> {
  static const _accountSuspendedKey = 'account_suspended_notice';

  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_accountSuspendedKey) ?? false;
  }

  Future<void> markSuspended() async {
    // Let a still-running build finish first so it cannot overwrite this.
    try {
      await future;
    } catch (_) {}
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_accountSuspendedKey, true);
    state = const AsyncData(true);
  }

  Future<void> acknowledge() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_accountSuspendedKey);
    state = const AsyncData(false);
  }
}

class AuthController extends AsyncNotifier<AuthSession?> {
  static const _installationInitializedKey = 'installation_initialized_v1';
  static const _onboardingCompleteKey = 'onboarding_complete';

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TermsAcceptanceStore get _termsStore =>
      ref.read(termsAcceptanceStoreProvider);
  ProfileRemoteDataSource get _profileRemoteDataSource =>
      ProfileRemoteDataSource(ref.read(apiServiceProvider));

  bool _handlingBan = false;

  @override
  Future<AuthSession?> build() async {
    // Any request can report that this account has been banned. Drop the
    // local session straight away instead of retrying with dead tokens.
    final bannedSubscription = ref
        .read(apiServiceProvider)
        .accountBannedEvents
        .listen((_) => unawaited(_handleAccountBanned()));
    ref.onDispose(bannedSubscription.cancel);

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
      _restoreSessionWithRetry(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    final restored = results[0] as AuthSession?;
    debugPrint(
      '[Auth] restoreSession complete: hasSession=${restored != null}, '
      'user=${restored?.user.id}',
    );
    if (restored == null) return null;

    final session = await _prepareSession(restored);
    if (session == null) return null;
    await _markOnboardingComplete();
    // Don't hold the splash on it; an unchanged token is not re-sent anyway.
    unawaited(_registerPushToken());
    // Retry a terms acceptance the server could not record earlier.
    unawaited(_syncPendingTermsAcceptance(restored.user));
    return session;
  }

  /// Restores the saved session. A transient failure (offline, timeout, 5xx)
  /// is retried with backoff and then rethrown: build() fails, the router
  /// keeps the user on the splash (see [authStatusProvider]) and the splash
  /// offers a retry. The saved tokens are kept throughout.
  Future<AuthSession?> _restoreSessionWithRetry() async {
    const backoff = [Duration(seconds: 1), Duration(seconds: 3)];
    for (var attempt = 0; ; attempt++) {
      try {
        return await _repository.restoreSession();
      } catch (error) {
        if (attempt >= backoff.length) rethrow;
        debugPrint('[Auth] restoreSession failed, retrying: $error');
        await Future<void>.delayed(backoff[attempt]);
      }
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final session = await _prepareSession(
        await ref.read(loginUseCaseProvider)(email: email, password: password),
      );
      if (session == null) {
        state = const AsyncData(null);
        return;
      }
      await _markOnboardingComplete();
      await _registerPushToken();
      state = AsyncData(session);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    try {
      // Also forgets this device's push-token registration.
      await _unregisterPushToken();
      // Revokes only this device's session; the saved tokens are cleared
      // even if the call fails (AuthRepositoryImpl.logout).
      await _repository.logout();
    } catch (error) {
      debugPrint('[Auth] remote logout failed: $error');
    } finally {
      // A failed server call must not leave the app stuck on the splash.
      await _clearLocalSession();
    }
  }

  /// Deletes the remote profile before clearing every locally stored trace of
  /// the session. This must not call logout afterward: the account no longer
  /// exists once deletion has succeeded.
  Future<void> deleteAccount() async {
    final previous = state;
    state = const AsyncLoading();
    try {
      await ProfileRemoteDataSource(ref.read(apiServiceProvider)).deleteMe();
    } catch (_) {
      // Put the session back as it was if deletion did not complete, so the
      // user can retry rather than being incorrectly told it was deleted.
      state = previous;
      rethrow;
    }
    try {
      // The server deleted the whole user document, device tokens included;
      // only the local registration record is left to forget.
      await PushNotificationService.clearRegistrationCache();
      await ref.read(secureStorageServiceProvider).clearTokens();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('pro_entitlement', false);
    } finally {
      await _clearLocalSession();
    }
  }

  Future<void> _clearLocalSession({bool resetState = true}) async {
    await ref.read(onboardingDraftProvider.notifier).clear();
    ref.read(onboardingProfileImageProvider.notifier).state = null;
    await ref.read(onboardingCompletionProvider.notifier).reset();
    await ref.read(shareTutorialCompletionProvider.notifier).reset();
    ref.read(deferredInteractionTokenProvider.notifier).state = null;
    ref.read(deferredShareCodeProvider.notifier).state = null;
    ref.read(deferredInteractionTypeProvider.notifier).state = null;
    if (resetState) state = const AsyncData(null);
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
      final session = await _prepareSession(
        await ref.read(signUpUseCaseProvider)(
          name: name,
          email: email,
          password: password,
          instagramId: instagramId,
          avatarUrl: avatarUrl,
        ),
      );
      if (session == null) {
        state = const AsyncData(null);
        return;
      }
      await _markOnboardingComplete();
      await _registerPushToken();
      state = AsyncData(session);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final serverUser =
          await ref.read(authRemoteDataSourceProvider).getCurrentUser();
      if (serverUser.isBanned) {
        await _handleAccountBanned();
        return;
      }
      // Keep a terms acceptance the server has not recorded yet, otherwise a
      // refresh would send the user back to the terms gate.
      _replaceUser(await _applyLocalTermsAcceptanceTo(serverUser));
    } catch (e) {
      debugPrint('[Auth] refreshUser failed: $e');
    }
  }

  /// Puts [user], as the server just returned it (e.g. from PATCH
  /// /profiles/me), into the session without another /auth/me round trip.
  /// Handled like [refreshUser]: a banned account is signed out, and a terms
  /// acceptance so far known only on this device is kept. Skipped when the
  /// session was signed out or belongs to someone else, or nothing changed.
  void setUser(AppUser user) {
    if (user.isBanned) {
      unawaited(_handleAccountBanned());
      return;
    }
    final current = state.valueOrNull?.user;
    if (current != null &&
        current.id == user.id &&
        (current.termsVersion ?? 0) > (user.termsVersion ?? 0)) {
      // The server has an older terms version than this device recorded;
      // dropping it would send the user straight back to the terms gate.
      _replaceUser(
        user.copyWith(
          termsVersion: current.termsVersion,
          termsAcceptedAt: current.termsAcceptedAt,
        ),
      );
      return;
    }
    _replaceUser(user);
  }

  /// Called only after the user has explicitly restored a Pro store purchase.
  /// A saved Keychain session is accepted only when its server profile is Pro.
  Future<bool> restoreProProfile() async {
    final restored = await _repository.restoreProSession();
    if (restored == null) return false;
    final session = await _prepareSession(restored);
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
    final prepared = await _prepareSession(session);
    if (prepared == null) return;
    await _markOnboardingComplete();
    await _registerPushToken();
    state = AsyncData(prepared);
  }

  /// Creates the guest account at the end of onboarding.
  ///
  /// [acceptedTermsVersion] is the Terms/Community Guidelines version the
  /// user agreed to on the sign-up rules screen, before the account existed.
  Future<void> guestRegister({
    required int age,
    required String displayName,
    required String username,
    String? instagramId,
    String? snapchatId,
    String? avatarUrl,
    String? deviceId,
    int? acceptedTermsVersion,
  }) async {
    debugPrint(
      '[Auth] guestRegister start: username=$username, displayName=$displayName, '
      'deviceId=$deviceId',
    );
    state = const AsyncLoading();
    try {
      final created = await _repository.guestRegister(
        age: age,
        displayName: displayName,
        username: username,
        instagramId: instagramId,
        snapchatId: snapchatId,
        avatarUrl: avatarUrl,
        deviceId: deviceId,
        acceptedTermsVersion: acceptedTermsVersion,
      );
      debugPrint('[Auth] guestRegister success: token received and saved');
      if (created.user.isBanned) {
        await _handleAccountBanned();
        throw const AppException(
          CommunityRules.accountSuspendedMessage,
          statusCode: 403,
          code: AppErrorCodes.accountBanned,
        );
      }
      final session =
          acceptedTermsVersion == null
              ? created
              : await _recordSignUpTermsAcceptance(
                created,
                acceptedTermsVersion,
              );
      state = AsyncData(session);
      unawaited(_registerPushToken());
    } catch (e, st) {
      debugPrint('[Auth] guestRegister failed: $e');
      debugPrint('[Auth] guestRegister stacktrace: $st');
      state = AsyncError(e, st);
    }
  }

  /// Records that the signed-in user agreed to the current Terms of Use and
  /// Community Guidelines (the terms gate for existing users).
  ///
  /// The server is told first. If it cannot record it (endpoint not deployed
  /// yet, offline), the acceptance is kept on this device and synced on a
  /// later launch (at most once a day), so the gate never blocks a user who
  /// has agreed. Ends with a single state write.
  Future<void> acceptCurrentTerms() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final userId = current.user.id;
    const version = kCurrentTermsVersion;

    AppUser user;
    try {
      final serverUser = await _profileRemoteDataSource.acceptTerms(
        version: version,
      );
      if (serverUser.isBanned) {
        await _handleAccountBanned();
        return;
      }
      if ((serverUser.termsVersion ?? 0) >= version) {
        user = serverUser;
      } else {
        final acceptedAt = DateTime.now().toUtc();
        await _saveLocalTermsAcceptance(
          userId,
          version: version,
          acceptedAt: acceptedAt,
        );
        user = serverUser.copyWith(
          termsVersion: version,
          termsAcceptedAt: acceptedAt,
        );
      }
    } catch (error) {
      // A banned account is handled by _handleAccountBanned via the API.
      if (error is AppException && error.isAccountBanned) return;
      debugPrint(
        '[Auth] terms acceptance not recorded by the server, keeping it on '
        'this device: $error',
      );
      final acceptedAt = DateTime.now().toUtc();
      await _saveLocalTermsAcceptance(
        userId,
        version: version,
        acceptedAt: acceptedAt,
      );
      user = current.user.copyWith(
        termsVersion: version,
        termsAcceptedAt: acceptedAt,
      );
    }

    // One state write: the router then leaves the terms gate.
    _replaceUser(user);
  }

  /// Puts [user] into the current session with a single state write. Skipped
  /// when nothing changed (every write refetches the user's feeds) or when
  /// the session was signed out or replaced in the meantime.
  void _replaceUser(AppUser user) {
    final latest = state.valueOrNull;
    if (latest == null || latest.user.id != user.id || latest.user == user) {
      return;
    }
    state = AsyncData(latest.copyWith(user: user));
  }

  /// Checks shared by every newly signed-in or restored session: a banned
  /// account is rejected (returns null) and terms accepted on this device are
  /// applied.
  Future<AuthSession?> _prepareSession(AuthSession session) async {
    if (session.user.isBanned) {
      await _handleAccountBanned();
      return null;
    }
    return _withLocalTermsAcceptance(session);
  }

  Future<AuthSession> _withLocalTermsAcceptance(AuthSession session) async {
    final user = await _applyLocalTermsAcceptanceTo(session.user);
    return identical(user, session.user)
        ? session
        : session.copyWith(user: user);
  }

  Future<AppUser> _applyLocalTermsAcceptanceTo(AppUser user) async {
    if (user.hasAcceptedCurrentTerms) return user;
    try {
      return applyLocalTermsAcceptance(user, await _termsStore.read(user.id));
    } catch (error) {
      debugPrint('[Auth] reading local terms acceptance failed: $error');
      return user;
    }
  }

  /// The user agreed to [version] on the sign-up rules screen before the
  /// account existed. If the backend did not record it (an older deploy that
  /// ignores `acceptedTermsVersion`), remember it on this device so the user
  /// is not asked again, and sync it on a later launch.
  Future<AuthSession> _recordSignUpTermsAcceptance(
    AuthSession session,
    int version,
  ) async {
    final user = session.user;
    if ((user.termsVersion ?? 0) >= version) return session;
    final acceptedAt = DateTime.now().toUtc();
    await _saveLocalTermsAcceptance(
      user.id,
      version: version,
      acceptedAt: acceptedAt,
    );
    return session.copyWith(
      user: user.copyWith(termsVersion: version, termsAcceptedAt: acceptedAt),
    );
  }

  /// Saves an acceptance the server was just asked to record but didn't; it
  /// is synced later (at most once a day).
  Future<void> _saveLocalTermsAcceptance(
    String userId, {
    required int version,
    required DateTime acceptedAt,
  }) async {
    try {
      await _termsStore.savePending(
        userId,
        version: version,
        acceptedAt: acceptedAt,
        syncAttemptedAt: DateTime.now(),
      );
    } catch (error) {
      debugPrint('[Auth] saving local terms acceptance failed: $error');
    }
  }

  /// Retries telling the server about an acceptance only this device knows
  /// about — at most once per [LocalTermsAcceptance.syncRetryInterval], and
  /// never again once it succeeds. [serverUser] is the user exactly as the
  /// server returned it.
  Future<void> _syncPendingTermsAcceptance(AppUser serverUser) async {
    try {
      final local = await _termsStore.read(serverUser.id);
      if (local == null || !local.pendingSync) return;
      if ((serverUser.termsVersion ?? 0) >= local.version) {
        await _termsStore.markSynced(serverUser.id);
        return;
      }
      final now = DateTime.now();
      if (!local.isSyncDue(now)) return;
      await _termsStore.recordSyncAttempt(serverUser.id, now);
      final synced = await _profileRemoteDataSource.acceptTerms(
        version: local.version,
      );
      if (synced.isBanned) {
        await _handleAccountBanned();
        return;
      }
      // Not recorded (unexpected response): the next attempt is a day away.
      if ((synced.termsVersion ?? 0) < local.version) return;
      await _termsStore.markSynced(serverUser.id);
      // No state write: the session already shows the acceptance.
      debugPrint('[Auth] pending terms acceptance synced');
    } catch (error) {
      debugPrint('[Auth] terms acceptance sync deferred: $error');
    }
  }

  /// The backend reported this account (or device) as banned. Forget the
  /// session locally, without calling logout/push endpoints that would only
  /// be rejected, and raise the suspension notice for the router.
  Future<void> _handleAccountBanned() async {
    if (_handlingBan) return;
    _handlingBan = true;
    try {
      debugPrint('[Auth] account suspended: clearing local session');
      // Flag first so the router goes straight to the notice rather than
      // briefly to onboarding when the session disappears.
      await ref.read(accountSuspendedProvider.notifier).markSuspended();
      try {
        await ref.read(secureStorageServiceProvider).clearTokens();
      } catch (error) {
        debugPrint('[Auth] clearing tokens after ban failed: $error');
      }
      await PushNotificationService.clearRegistrationCache();
      await _clearLocalSession(resetState: false);
      // An operation still in flight (session restore, sign-up, logout)
      // settles the state itself — e.g. guest-register reports the ban as
      // its error. Otherwise sign out now, if there is a session to drop.
      if (!state.isLoading && state.valueOrNull != null) {
        state = const AsyncData(null);
      }
    } catch (error) {
      debugPrint('[Auth] clearing banned session failed: $error');
    } finally {
      _handlingBan = false;
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
