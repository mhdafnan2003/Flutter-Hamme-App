import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/community_guidelines_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/settings_providers.dart';
import 'package:hamme_app/routes/route_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedInAuthController extends AuthController {
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
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings lists preference and external link options', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Safety & support'), findsOneWidget);
    expect(find.text('Community Guidelines'), findsOneWidget);
    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text('support@hamme.app'), findsOneWidget);
    expect(find.text('Report a safety concern'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Safety resources'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('community guidelines open in the app', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
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

    await tester.tap(find.text('Community Guidelines'));
    await tester.pumpAndSettle();

    expect(find.text('Zero tolerance'), findsOneWidget);
    expect(find.text('Not allowed on Hamme'), findsOneWidget);
  });

  testWidgets('contact falls back to showing the address without a mail app', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];
    messenger.setMockMethodCallHandler(urlLauncher, (call) async {
      launchedUrls.add((call.arguments as Map)['url'] as String);
      return false; // No mail app can take it.
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(urlLauncher, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SignedInAuthController.new),
      ],
    );
    addTearDown(container.dispose);
    // In the app the router keeps the signed-in session alive.
    container.listen(authControllerProvider, (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Contact us'));
    await tester.pumpAndSettle();

    final mail = Uri.parse(launchedUrls.single);
    expect(mail.scheme, 'mailto');
    expect(mail.path, 'support@hamme.app');
    expect(mail.query, startsWith('subject=Hamme%20support&body='));
    expect(Uri.decodeComponent(mail.query), contains('Share code: harshit'));
    expect(Uri.decodeComponent(mail.query), contains('User ID: user-1'));

    expect(find.text('Contact Hamme'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('support@hamme.app'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Copy email'));
    await tester.pumpAndSettle();
    expect(find.text('Contact Hamme'), findsNothing);
    expect(find.text('Email address copied.'), findsOneWidget);
  });

  testWidgets('notification controls can be changed', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: NotificationsSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNWidgets(3));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings_match_notifications'), isFalse);
  });

  testWidgets('delete account asks for confirmation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete account?'), findsOneWidget);
    expect(
      find.textContaining('This permanently deletes your profile'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
  });

  testWidgets('appearance control changes the selected theme', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppearanceSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('settings_theme_mode'), 'dark');
  });
}
