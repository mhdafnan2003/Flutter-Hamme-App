import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../utils/constants/text_strings.dart';
import 'auth_providers.dart';
import 'onboarding_photo_provider.dart';
import 'onboarding_providers.dart';

final onboardingRegistrationProvider =
    NotifierProvider<OnboardingRegistration, AsyncValue<bool>>(
      OnboardingRegistration.new,
    );

/// Keeps registration alive while the username screen is replaced by Pro.
class OnboardingRegistration extends Notifier<AsyncValue<bool>> {
  Future<bool>? _pending;
  bool _disposed = false;

  @override
  AsyncValue<bool> build() {
    ref.onDispose(() => _disposed = true);
    return const AsyncData(false);
  }

  Future<bool> start() {
    if (_pending != null) return _pending!;
    if (ref.read(authControllerProvider).valueOrNull != null) {
      return Future.value(true);
    }
    state = const AsyncLoading();
    return _pending = _register().whenComplete(() => _pending = null);
  }

  Future<bool> _register() async {
    try {
      final draft = ref.read(onboardingDraftProvider).valueOrNull;
      if (draft == null || draft.username == null) {
        throw const AppException('Onboarding data is missing.');
      }
      final acceptedTerms = draft.termsAcceptedVersion;
      if (acceptedTerms == null || acceptedTerms < kCurrentTermsVersion) {
        throw const AppException('Please agree to the community rules first.');
      }
      final age =
          draft.birthday == null
              ? 18
              : (DateTime.now().difference(draft.birthday!).inDays / 365.25)
                  .floor();
      await ref
          .read(authControllerProvider.notifier)
          .guestRegister(
            age: age.clamp(13, 100),
            displayName: (draft.name ?? 'Guest').trim(),
            username: draft.username!,
            instagramId:
                draft.socialPlatform == TTexts.socialInstagram
                    ? draft.username
                    : null,
            snapchatId:
                draft.socialPlatform == TTexts.socialSnapchat
                    ? draft.username
                    : null,
            acceptedTermsVersion: acceptedTerms,
          );
      if (_disposed) return false;
      final auth = ref.read(authControllerProvider);
      if (auth.hasError || auth.valueOrNull == null) {
        throw auth.error ??
            const AppException('Could not create your account. Try again.');
      }
      state = const AsyncData(true);
      unawaited(ref.read(onboardingPhotoUploadProvider.notifier).syncProfile());
      return true;
    } catch (error, stack) {
      if (!_disposed) state = AsyncError(error, stack);
      return false;
    }
  }
}
