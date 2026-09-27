import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/services/push_notification_service.dart';
import 'package:hamme_app/core/services/secure_storage_service.dart';
import 'package:hamme_app/core/services/terms_acceptance_store.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/push_notification_providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokenStorage extends SecureStorageService {
  _MemoryTokenStorage({this.accessToken, this.refreshToken})
    : super(const FlutterSecureStorage());

  String? accessToken;
  String? refreshToken;

  @override
  Future<void> storeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _NoopPushService implements PushNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> handleInitialMessage() async {}

  @override
  Future<void> registerToken() async {}

  @override
  Future<void> unregisterToken() async {}
}

const _userId = 'user-1';

Map<String, dynamic> _userJson({int? termsVersion, bool isBanned = false}) => {
  'id': _userId,
  'name': 'Harshit',
  'email': '',
  'instagramId': 'harshit',
  'shareCode': 'harshit',
  'isPro': false,
  'termsVersion': termsVersion,
  'termsAcceptedAt': termsVersion == null ? null : '2026-09-01T10:00:00.000Z',
  'isBanned': isBanned,
};

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status);

/// A fake backend. [termsRoute] answers `POST /profiles/me/terms`.
class _Backend {
  _Backend({
    this.meUser,
    this.meStatus = 200,
    this.termsRoute,
    this.guestRegisterUser,
  });

  Map<String, dynamic>? meUser;
  int meStatus;
  http.Response Function()? termsRoute;
  Map<String, dynamic>? guestRegisterUser;

  int termsPosts = 0;
  Map<String, dynamic>? lastGuestRegisterBody;

  late final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/me')) {
      if (meStatus != 200) {
        return _json({
          'message':
              'Your account has been suspended for violating the Hamme Terms '
              'of Use.',
          'details': {'code': 'ACCOUNT_BANNED'},
        }, meStatus);
      }
      return _json({'user': meUser}, 200);
    }
    if (path.endsWith('/profiles/me/terms')) {
      termsPosts++;
      return termsRoute?.call() ?? _json({'message': 'Route not found.'}, 404);
    }
    if (path.endsWith('/auth/guest-register')) {
      lastGuestRegisterBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
        'user': guestRegisterUser,
      }, 201);
    }
    return _json({}, 200);
  });
}

ProviderContainer _launch(_Backend backend, _MemoryTokenStorage storage) {
  return ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(backend.client),
      secureStorageServiceProvider.overrideWithValue(storage),
      pushNotificationServiceProvider.overrideWithValue(_NoopPushService()),
    ],
  );
}

Map<String, Object> _existingInstall([Map<String, Object> extra = const {}]) {
  return {
    'installation_initialized_v1': true,
    'onboarding_complete': true,
    ...extra,
  };
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://example.test/api/v1');
  });

  group('AppUser terms and ban fields', () {
    test('parse from the API and default when missing', () {
      final accepted = AppUser.fromJson(_userJson(termsVersion: 1));
      expect(accepted.termsVersion, 1);
      expect(accepted.termsAcceptedAt, DateTime.utc(2026, 9, 1, 10));
      expect(accepted.hasAcceptedCurrentTerms, isTrue);
      expect(accepted.isBanned, isFalse);

      final legacy = AppUser.fromJson({
        'id': _userId,
        'name': 'Harshit',
        'email': '',
        'instagramId': '',
        'shareCode': 'harshit',
      });
      expect(legacy.termsVersion, isNull);
      expect(legacy.hasAcceptedCurrentTerms, isFalse);
      expect(legacy.isBanned, isFalse);
    });

    test('unexpected types never break parsing', () {
      final user = AppUser.fromJson({
        ..._userJson(),
        'termsVersion': '1',
        'termsAcceptedAt': 12345,
        'isBanned': 'yes',
      });
      expect(user.termsVersion, 1);
      expect(user.termsAcceptedAt, isNull);
      expect(user.isBanned, isFalse);
    });
  });

  group('local terms acceptance', () {
    test('applies only when the server has not recorded it', () {
      final local = LocalTermsAcceptance(
        version: 1,
        acceptedAt: DateTime.utc(2026, 9, 2),
        pendingSync: true,
      );
      final serverless = AppUser.fromJson(_userJson());
      expect(
        applyLocalTermsAcceptance(serverless, local).hasAcceptedCurrentTerms,
        isTrue,
      );

      final server = AppUser.fromJson(_userJson(termsVersion: 1));
      expect(applyLocalTermsAcceptance(server, local), same(server));
      expect(applyLocalTermsAcceptance(serverless, null), same(serverless));
    });

    test('sync is attempted at most once a day and stops once synced', () {
      final now = DateTime.utc(2026, 9, 25, 12);
      LocalTermsAcceptance withAttempt(DateTime? at, {bool pending = true}) =>
          LocalTermsAcceptance(
            version: 1,
            acceptedAt: now,
            pendingSync: pending,
            lastSyncAttemptAt: at,
          );

      expect(withAttempt(null).isSyncDue(now), isTrue);
      expect(
        withAttempt(now.subtract(const Duration(hours: 23))).isSyncDue(now),
        isFalse,
      );
      expect(
        withAttempt(now.subtract(const Duration(hours: 24))).isSyncDue(now),
        isTrue,
      );
      expect(withAttempt(null, pending: false).isSyncDue(now), isFalse);
    });
  });

  group('existing-user terms gate', () {
    test('agreeing without the backend endpoint is kept on the device and '
        'retried at most once a day', () async {
      SharedPreferences.setMockInitialValues(_existingInstall());
      final backend = _Backend(meUser: _userJson());
      final storage = _MemoryTokenStorage(
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      final firstLaunch = _launch(backend, storage);
      final session = await firstLaunch.read(authControllerProvider.future);
      expect(session!.user.hasAcceptedCurrentTerms, isFalse);
      expect(firstLaunch.read(currentUserTermsAcceptedProvider), isFalse);

      await firstLaunch
          .read(authControllerProvider.notifier)
          .acceptCurrentTerms();
      expect(backend.termsPosts, 1);
      expect(firstLaunch.read(currentUserTermsAcceptedProvider), isTrue);
      firstLaunch.dispose();

      final local = await TermsAcceptanceStore().read(_userId);
      expect(local?.pendingSync, isTrue);
      expect(local?.lastSyncAttemptAt, isNotNull);

      // Next launch: the server still doesn't know, yet the user is not
      // asked again and the sync waits until a day has passed.
      final secondLaunch = _launch(backend, storage);
      final restored = await secondLaunch.read(authControllerProvider.future);
      await pumpEventQueue(times: 50);
      expect(restored!.user.hasAcceptedCurrentTerms, isTrue);
      expect(secondLaunch.read(currentUserTermsAcceptedProvider), isTrue);
      expect(backend.termsPosts, 1);
      secondLaunch.dispose();
    });

    test(
      'a pending acceptance syncs once a day has passed, then stops',
      () async {
        final dayAgo = DateTime.now().toUtc().subtract(
          const Duration(hours: 25),
        );
        SharedPreferences.setMockInitialValues(
          _existingInstall({
            'terms_accepted_version_$_userId': 1,
            'terms_accepted_at_$_userId': dayAgo.toIso8601String(),
            'terms_pending_sync_$_userId': true,
            'terms_sync_attempted_at_$_userId': dayAgo.toIso8601String(),
          }),
        );
        final backend = _Backend(
          meUser: _userJson(),
          termsRoute: () => _json({'user': _userJson(termsVersion: 1)}, 200),
        );
        final storage = _MemoryTokenStorage(accessToken: 'access');

        final launch = _launch(backend, storage);
        final session = await launch.read(authControllerProvider.future);
        await pumpEventQueue(times: 50);
        expect(session!.user.hasAcceptedCurrentTerms, isTrue);
        expect(backend.termsPosts, 1);
        expect(
          (await TermsAcceptanceStore().read(_userId))?.pendingSync,
          isFalse,
        );
        launch.dispose();

        final nextLaunch = _launch(backend, storage);
        await nextLaunch.read(authControllerProvider.future);
        await pumpEventQueue(times: 50);
        expect(backend.termsPosts, 1);
        nextLaunch.dispose();
      },
    );

    test(
      'agreeing with the backend endpoint records it on the server',
      () async {
        SharedPreferences.setMockInitialValues(_existingInstall());
        final backend = _Backend(
          meUser: _userJson(),
          termsRoute: () => _json({'user': _userJson(termsVersion: 1)}, 200),
        );
        final launch = _launch(
          backend,
          _MemoryTokenStorage(accessToken: 'access'),
        );
        addTearDown(launch.dispose);
        await launch.read(authControllerProvider.future);

        await launch.read(authControllerProvider.notifier).acceptCurrentTerms();

        expect(backend.termsPosts, 1);
        expect(launch.read(currentUserTermsAcceptedProvider), isTrue);
        expect(await TermsAcceptanceStore().read(_userId), isNull);
      },
    );
  });

  group('sign-up agreement', () {
    Future<(ProviderContainer, _Backend)> signUp({
      required Map<String, dynamic> createdUser,
    }) async {
      SharedPreferences.setMockInitialValues(const {
        'installation_initialized_v1': true,
      });
      final backend = _Backend(guestRegisterUser: createdUser);
      final launch = _launch(backend, _MemoryTokenStorage());
      addTearDown(launch.dispose);
      expect(await launch.read(authControllerProvider.future), isNull);

      await launch
          .read(authControllerProvider.notifier)
          .guestRegister(
            age: 19,
            displayName: 'Harshit',
            username: 'harshit',
            instagramId: 'harshit',
            acceptedTermsVersion: 1,
          );
      return (launch, backend);
    }

    test('sends the agreed version with guest-register', () async {
      final (launch, backend) = await signUp(
        createdUser: _userJson(termsVersion: 1),
      );
      expect(backend.lastGuestRegisterBody?['acceptedTermsVersion'], 1);
      expect(launch.read(currentUserTermsAcceptedProvider), isTrue);
      expect(await TermsAcceptanceStore().read(_userId), isNull);
    });

    test(
      'an older backend that ignores it does not re-prompt the user',
      () async {
        final (launch, _) = await signUp(createdUser: _userJson());
        expect(launch.read(currentUserTermsAcceptedProvider), isTrue);
        final local = await TermsAcceptanceStore().read(_userId);
        expect(local?.version, 1);
        expect(local?.pendingSync, isTrue);
      },
    );
  });

  group('banned accounts', () {
    test('a 403 ACCOUNT_BANNED signs out and shows the notice', () async {
      SharedPreferences.setMockInitialValues(_existingInstall());
      final backend = _Backend(meStatus: 403);
      final storage = _MemoryTokenStorage(
        accessToken: 'access',
        refreshToken: 'refresh',
      );
      final launch = _launch(backend, storage);
      addTearDown(launch.dispose);
      launch.listen(accountSuspendedProvider, (_, _) {});

      expect(await launch.read(authControllerProvider.future), isNull);
      await pumpEventQueue(times: 50);

      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(launch.read(accountSuspendedProvider).valueOrNull, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('onboarding_complete'), isFalse);
    });

    test('isBanned on /me is treated the same way', () async {
      SharedPreferences.setMockInitialValues(_existingInstall());
      final backend = _Backend(meUser: _userJson(isBanned: true));
      final storage = _MemoryTokenStorage(accessToken: 'access');
      final launch = _launch(backend, storage);
      addTearDown(launch.dispose);

      expect(await launch.read(authControllerProvider.future), isNull);
      await pumpEventQueue(times: 50);

      expect(storage.accessToken, isNull);
      expect(launch.read(accountSuspendedProvider).valueOrNull, isTrue);
    });

    test('acknowledging the notice clears it', () async {
      SharedPreferences.setMockInitialValues({
        'account_suspended_notice': true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(accountSuspendedProvider.future), isTrue);
      await container.read(accountSuspendedProvider.notifier).acknowledge();
      expect(container.read(accountSuspendedProvider).valueOrNull, isFalse);
    });
  });
}
