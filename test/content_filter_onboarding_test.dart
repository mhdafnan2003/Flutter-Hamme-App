import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/name_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/social_media_screen.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/pro_screen.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/routes/route_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records guest-register calls instead of hitting the network.
class _RecordingAuthController extends AuthController {
  _RecordingAuthController({this.error, this.pending});

  final Completer<void>? pending;

  final AppException? error;
  int calls = 0;
  int? acceptedTermsVersion;

  @override
  Future<AuthSession?> build() async => null;

  @override
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
    calls++;
    this.acceptedTermsVersion = acceptedTermsVersion;
    if (pending != null) await pending!.future;
    final error = this.error;
    if (error != null) {
      state = AsyncError(error, StackTrace.current);
    } else {
      state = const AsyncData(
        AuthSession(
          accessToken: 'token',
          user: AppUser(
            id: 'guest',
            name: 'Harshit',
            email: '',
            instagramId: 'harshit',
            shareCode: 'share',
            termsVersion: 1,
          ),
        ),
      );
    }
  }
}

class _Billing extends BillingController {
  int purchases = 0;
  @override
  BillingState build() => const BillingState();
  @override
  Future<void> buyPro() async {
    purchases++;
  }
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required String initialLocation,
  AuthController? auth,
  _Billing? billing,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/onboarding/pro', builder: (_, _) => const ProScreen()),
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/onboarding/name', builder: (_, _) => const NameScreen()),
      GoRoute(
        path: '/onboarding/social_media',
        builder: (_, _) => const SocialMediaScreen(),
      ),
      for (final path in [
        RoutePaths.onboardingCommunityRules,
        '/onboarding/profile_upload',
      ])
        GoRoute(path: path, builder: (_, _) => Text('screen $path')),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      billingControllerProvider.overrideWith(() => billing ?? _Billing()),
      if (auth != null) authControllerProvider.overrideWith(() => auth),
    ],
  );
  addTearDown(container.dispose);
  // In the app the router keeps the auth session alive from startup.
  if (auth != null) container.listen(authControllerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('name step rejects an objectionable name inline', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpOnboarding(tester, initialLocation: '/onboarding/name');
    const error = "That name isn't allowed on Hamme. Please choose another.";

    await tester.enterText(find.byType(TextField), 'Fuck Off');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text(error), findsOneWidget);
    expect(find.text('screen /onboarding/profile_upload'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Harshit Dikshit');
    await tester.pump();
    expect(find.text(error), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('screen /onboarding/profile_upload'), findsOneWidget);
  });

  testWidgets('social step rejects an objectionable handle inline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_name': 'Harshit',
      'onboarding_terms_accepted_version': 1,
    });
    final auth = _RecordingAuthController();
    await _pumpOnboarding(
      tester,
      initialLocation: '/onboarding/social_media',
      auth: auth,
    );

    await tester.enterText(find.byType(TextField), 'fuck.you');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "That Instagram username isn't allowed on Hamme. Please choose another.",
      ),
      findsOneWidget,
    );
    expect(auth.calls, 0);
  });

  testWidgets('a server rejection is shown on the handle field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_name': 'Harshit',
      'onboarding_terms_accepted_version': 1,
    });
    const message =
        "That username isn't allowed on Hamme. Please choose another.";
    final auth = _RecordingAuthController(
      error: const AppException(
        message,
        statusCode: 400,
        code: AppErrorCodes.objectionableContent,
        details: {'code': 'OBJECTIONABLE_CONTENT', 'field': 'username'},
      ),
    );
    await _pumpOnboarding(
      tester,
      initialLocation: '/onboarding/social_media',
      auth: auth,
    );

    await tester.enterText(find.byType(TextField), 'harshit');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(auth.calls, 1);
    expect(auth.acceptedTermsVersion, 1);
    expect(find.text(message), findsOneWidget);
    expect(find.text('screen /onboarding/pro'), findsNothing);
  });

  testWidgets(
    'Next opens Pro before registration finishes and purchase waits',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_name': 'Harshit',
        'onboarding_terms_accepted_version': 1,
      });
      final pending = Completer<void>();
      final auth = _RecordingAuthController(pending: pending);
      final billing = _Billing();
      await _pumpOnboarding(
        tester,
        initialLocation: '/onboarding/social_media',
        auth: auth,
        billing: billing,
      );
      await tester.enterText(find.byType(TextField), 'harshit');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(ProScreen), findsOneWidget);
      expect(auth.calls, 1);
      expect(pending.isCompleted, isFalse);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(billing.purchases, 0);
      pending.complete();
      await tester.pumpAndSettle();
      expect(billing.purchases, 1);
      expect(auth.calls, 1);
    },
  );

  testWidgets('closing Pro waits for registration before entering Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_name': 'Harshit',
      'onboarding_terms_accepted_version': 1,
    });
    final pending = Completer<void>();
    final auth = _RecordingAuthController(pending: pending);
    await _pumpOnboarding(
      tester,
      initialLocation: '/onboarding/social_media',
      auth: auth,
    );
    await tester.enterText(find.byType(TextField), 'harshit');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pro-close')));
    await tester.pump();
    expect(find.text('home'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(auth.calls, 1);
  });

  testWidgets('no account is created without agreeing to the rules', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_name': 'Harshit'});
    final auth = _RecordingAuthController();
    await _pumpOnboarding(
      tester,
      initialLocation: '/onboarding/social_media',
      auth: auth,
    );

    await tester.enterText(find.byType(TextField), 'harshit');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(auth.calls, 0);
    expect(
      find.text('screen ${RoutePaths.onboardingCommunityRules}'),
      findsOneWidget,
    );
  });
}
