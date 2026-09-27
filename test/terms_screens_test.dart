import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/constants/community_rules.dart';
import 'package:hamme_app/features/auth/presentation/screens/account_suspended_screen.dart';
import 'package:hamme_app/features/auth/presentation/screens/terms_acceptance_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/community_rules_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/community_guidelines_screen.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/routes/route_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  int acceptCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthSession?> build() async => const AuthSession(
    user: AppUser(
      id: 'user-1',
      name: 'Harshit',
      email: '',
      instagramId: 'harshit',
      shareCode: 'harshit',
    ),
    accessToken: 'access',
  );

  @override
  Future<void> acceptCurrentTerms() async => acceptCalls++;

  @override
  Future<void> logout() async => logoutCalls++;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sign-up rules step requires ticking the agreement', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.onboardingCommunityRules,
      routes: [
        GoRoute(
          path: RoutePaths.onboardingCommunityRules,
          builder: (_, _) => const CommunityRulesScreen(),
        ),
        GoRoute(
          path: '/onboarding/name',
          builder: (_, _) => const Text('name step'),
        ),
        GoRoute(
          path: RoutePaths.communityGuidelines,
          builder: (_, _) => const CommunityGuidelinesScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hamme community rules'), findsOneWidget);
    expect(
      find.textContaining('zero tolerance for objectionable content'),
      findsOneWidget,
    );

    // Not agreed yet: the button does nothing.
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(find.text('name step'), findsNothing);

    await tester.tap(find.text(CommunityRules.agreementLabel));
    await tester.pump();
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();

    expect(find.text('name step'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('onboarding_terms_accepted_version'), 1);
  });

  testWidgets('sign-up rules link to the in-app community guidelines', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.onboardingCommunityRules,
      routes: [
        GoRoute(
          path: RoutePaths.onboardingCommunityRules,
          builder: (_, _) => const CommunityRulesScreen(),
        ),
        GoRoute(
          path: RoutePaths.communityGuidelines,
          builder: (_, _) => const CommunityGuidelinesScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Community Guidelines'));
    await tester.tap(find.text('Community Guidelines'));
    await tester.pumpAndSettle();

    expect(find.text('Not allowed on Hamme'), findsOneWidget);
  });

  testWidgets('terms gate requires agreement and offers a way out', (
    tester,
  ) async {
    final auth = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => auth)],
        child: const MaterialApp(home: TermsAcceptanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Our community rules'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.tap(find.text('I agree'));
    await tester.pump();
    expect(auth.acceptCalls, 0);

    await tester.tap(find.text(CommunityRules.agreementLabel));
    await tester.pump();
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(auth.acceptCalls, 1);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 1);
  });

  testWidgets('suspended accounts see the reason and the support address', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AccountSuspendedScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account suspended'), findsOneWidget);
    expect(find.text(CommunityRules.accountSuspendedMessage), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });

  testWidgets('community guidelines cover rules, reporting and contact', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunityGuidelinesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(CommunityRules.zeroToleranceStatement), findsOneWidget);
    for (final text in [
      'Bullying or harassment',
      'Hide, report, or block',
      CommunityRules.reviewPromise,
      'support@hamme.app',
      CommunityRules.emergencyNotice,
    ]) {
      await tester.scrollUntilVisible(find.text(text), 200);
      expect(find.text(text), findsOneWidget, reason: 'Missing "$text"');
    }
  });
}
