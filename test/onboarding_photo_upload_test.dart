import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/services/api_service.dart';
import 'package:hamme_app/core/services/secure_storage_service.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_photo_provider.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const user = AppUser(
  id: 'one',
  name: 'Guest',
  email: '',
  instagramId: 'guest',
  shareCode: 'share',
);

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(user: user, accessToken: 'token');

  @override
  void setUser(AppUser user) {
    state = AsyncData(state.value!.copyWith(user: user));
  }

  void signOut() => state = const AsyncData(null);
}

class _Api extends ApiService {
  _Api()
    : super(
        client: http.Client(),
        storage: SecureStorageService(const FlutterSecureStorage()),
      );
  final uploads = <Completer<Map<String, dynamic>>>[];
  final patches = <Object?>[];
  bool failPatch = false;

  @override
  Future<dynamic> postMultipart(
    String path, {
    required List<http.MultipartFile> files,
    Map<String, String>? fields,
    bool authenticated = false,
  }) {
    expect(path, '/upload/onboarding-profile-image');
    expect(authenticated, isFalse);
    final pending = Completer<Map<String, dynamic>>();
    uploads.add(pending);
    return pending.future;
  }

  @override
  Future<dynamic> patch(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    expect(authenticated, isTrue);
    patches.add(body);
    if (failPatch) throw Exception('profile update offline');
    return {
      'user':
          user
              .copyWith(avatarUrl: (body as Map)['avatarUrl'] as String)
              .toJson(),
    };
  }
}

void main() {
  late ProviderContainer container;
  late _Api api;
  late _Auth auth;
  late OnboardingPhotoUpload upload;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    auth = _Auth();
    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(() => auth),
      ],
    );
    await container.read(onboardingDraftProvider.future);
    await container.read(authControllerProvider.future);
    upload = container.read(onboardingPhotoUploadProvider.notifier);
  });
  tearDown(() => container.dispose());

  void select(String name) {
    container.read(onboardingProfileImageProvider.notifier).state =
        OnboardingProfileImage(bytes: Uint8List.fromList([1]), filename: name);
  }

  test(
    'selection starts immediately and sync reuses the pending upload',
    () async {
      select('first.jpg');
      final started = upload.start();
      final sync = upload.syncProfile();
      expect(api.uploads, hasLength(1));
      expect(api.patches, isEmpty);
      expect(identical(sync, upload.syncProfile()), isTrue);
      api.uploads.single.complete({'imageUrl': 'https://image/first.jpg'});
      await started;
      await sync;
      expect(api.patches, [
        {'avatarUrl': 'https://image/first.jpg'},
      ]);
      expect(container.read(onboardingProfileImageProvider), isNull);
      expect(
        container.read(authControllerProvider).value!.user.avatarUrl,
        'https://image/first.jpg',
      );
    },
  );

  test('an older selection cannot overwrite the newer upload', () async {
    select('first.jpg');
    final first = upload.start();
    select('second.jpg');
    final second = upload.start();
    api.uploads[1].complete({'imageUrl': 'https://image/second.jpg'});
    await second;
    api.uploads[0].complete({'imageUrl': 'https://image/first.jpg'});
    await first;
    expect(
      container.read(onboardingPhotoUploadProvider).value,
      'https://image/second.jpg',
    );
    await upload.syncProfile();
    expect(api.uploads, hasLength(2));
    expect(api.patches, [
      {'avatarUrl': 'https://image/second.jpg'},
    ]);
  });

  test('failure keeps the preview and can be retried', () async {
    select('first.jpg');
    final first = upload.start();
    api.uploads.single.completeError(Exception('offline'));
    expect(await first, isNull);
    expect(container.read(onboardingProfileImageProvider), isNotNull);
    expect(container.read(onboardingPhotoUploadProvider).hasError, isTrue);
    final retry = upload.syncProfile();
    api.uploads.last.complete({'imageUrl': 'https://image/retry.jpg'});
    await retry;
    expect(api.patches, [
      {'avatarUrl': 'https://image/retry.jpg'},
    ]);
  });

  test('profile update retry reuses the uploaded image URL', () async {
    select('first.jpg');
    api.failPatch = true;
    final first = upload.syncProfile();
    api.uploads.single.complete({'imageUrl': 'https://image/first.jpg'});
    await first;
    expect(container.read(onboardingProfileImageProvider), isNotNull);
    api.failPatch = false;
    await upload.syncProfile();
    expect(api.uploads, hasLength(1));
    expect(api.patches, hasLength(2));
    expect(container.read(onboardingProfileImageProvider), isNull);
  });

  test('signing out during upload prevents updating another profile', () async {
    select('first.jpg');
    final sync = upload.syncProfile();
    auth.signOut();
    container.read(onboardingProfileImageProvider.notifier).state = null;
    api.uploads.single.complete({'imageUrl': 'https://image/first.jpg'});
    await sync;
    expect(api.patches, isEmpty);
    expect(
      container.read(onboardingDraftProvider).value!.profileImageUrl,
      isNull,
    );
  });
}
