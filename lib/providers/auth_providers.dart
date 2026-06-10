import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_use_case.dart';
import '../features/auth/domain/usecases/sign_up_use_case.dart';
import '../models/auth_session.dart';
import 'api_providers.dart';
import 'deferred_interaction_provider.dart';
import 'onboarding_providers.dart';

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
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() async {
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
    return restored;
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(loginUseCaseProvider)(email: email, password: password),
    );
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await _repository.logout();
    await ref.read(onboardingDraftProvider.notifier).clear();
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
    state = await AsyncValue.guard(
      () => ref.read(signUpUseCaseProvider)(
        name: name,
        email: email,
        password: password,
        instagramId: instagramId,
        avatarUrl: avatarUrl,
      ),
    );
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
      debugPrint('[Auth] onboardingComplete save trigger');
      await ref.read(onboardingCompletionProvider.notifier).markComplete();
      ref.invalidate(onboardingCompletionProvider);
      debugPrint('[Auth] onboardingComplete provider invalidated');
      state = AsyncData(session);
    } catch (e, st) {
      debugPrint('[Auth] guestRegister failed: $e');
      debugPrint('[Auth] guestRegister stacktrace: $st');
      state = AsyncError(e, st);
    }
  }
}
