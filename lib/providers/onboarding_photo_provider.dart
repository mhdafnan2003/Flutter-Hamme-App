import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/data/datasources/upload_remote_data_source.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import 'onboarding_providers.dart';

final onboardingPhotoUploadProvider =
    NotifierProvider<OnboardingPhotoUpload, AsyncValue<String?>>(
      OnboardingPhotoUpload.new,
    );

/// Owns the upload across screen changes. The selected bytes remain available
/// for previews and retries until the server profile has been updated.
class OnboardingPhotoUpload extends Notifier<AsyncValue<String?>> {
  OnboardingProfileImage? _image;
  Future<String?>? _upload;
  String? _uploadedUrl;
  Future<void>? _sync;
  bool _disposed = false;

  @override
  AsyncValue<String?> build() {
    ref.onDispose(() => _disposed = true);
    return const AsyncData(null);
  }

  Future<String?> start() {
    final image = ref.read(onboardingProfileImageProvider);
    if (image == null) return Future.value(null);
    if (identical(image, _image) && _uploadedUrl != null) {
      state = AsyncData(_uploadedUrl);
      return Future.value(_uploadedUrl);
    }
    if (identical(image, _image) && _upload != null && !state.hasError) {
      return _upload!;
    }
    _image = image;
    _uploadedUrl = null;
    state = const AsyncLoading();
    return _upload = _uploadImage(image);
  }

  bool _isCurrent(OnboardingProfileImage image) =>
      !_disposed && identical(ref.read(onboardingProfileImageProvider), image);

  Future<String?> _uploadImage(OnboardingProfileImage image) async {
    try {
      final url = await UploadRemoteDataSource(
        ref.read(apiServiceProvider),
      ).uploadProfileImageBytes(
        bytes: image.bytes,
        filename: image.filename,
        onboarding: true,
      );
      if (_isCurrent(image)) {
        _uploadedUrl = url;
        state = AsyncData(url);
      }
      return url;
    } catch (error, stack) {
      if (_isCurrent(image)) state = AsyncError(error, stack);
      return null;
    }
  }

  /// Called without awaiting after registration, and on onboarding completion
  /// to retry a failed upload. Reuses an upload that is already in flight.
  Future<void> syncProfile() =>
      _sync ??= _syncProfile().whenComplete(() {
        _sync = null;
      });

  Future<void> _syncProfile() async {
    final image = ref.read(onboardingProfileImageProvider);
    final userId = ref.read(authControllerProvider).valueOrNull?.user.id;
    if (image == null || userId == null) return;
    try {
      final url = await start();
      if (url == null || !_isCurrent(image)) return;
      if (ref.read(authControllerProvider).valueOrNull?.user.id != userId) {
        return;
      }
      final user = await ProfileRemoteDataSource(
        ref.read(apiServiceProvider),
      ).updateMe(avatarUrl: url);
      if (!_isCurrent(image) ||
          ref.read(authControllerProvider).valueOrNull?.user.id != userId) {
        return;
      }
      await ref.read(onboardingDraftProvider.notifier).setProfileImageUrl(url);
      if (!_isCurrent(image) ||
          ref.read(authControllerProvider).valueOrNull?.user.id != userId) {
        return;
      }
      ref.read(authControllerProvider.notifier).setUser(user);
      ref.read(onboardingProfileImageProvider.notifier).state = null;
    } catch (error, stack) {
      if (_isCurrent(image)) state = AsyncError(error, stack);
    }
  }
}
