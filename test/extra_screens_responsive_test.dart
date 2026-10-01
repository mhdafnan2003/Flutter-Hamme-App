import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/auth/presentation/screens/account_suspended_screen.dart';
import 'package:hamme_app/features/auth/presentation/screens/terms_acceptance_screen.dart';
import 'package:hamme_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:hamme_app/features/safety/presentation/screens/blocked_users_screen.dart';
import 'package:hamme_app/features/safety/domain/models/blocked_users.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/safety_providers.dart';
import 'package:hamme_app/utils/theme/theme.dart';
import 'package:hamme_app/core/widgets/gradient_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LongNameAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    user: AppUser(
      id: 'compact-profile',
      name: 'A very long display name that should wrap inside a compact phone',
      email: '',
      instagramId: 'a_long_instagram_username',
      shareCode: 'example',
    ),
    accessToken: 'test',
  );
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: 'SHOW_DEV_LOGOUT_BUTTON=false');
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'));
    await font.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    BlockedUsersResult blocked = const BlockedUsersResult(),
    Size size = const Size(320, 480),
    double textScale = 2,
    EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 16),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_LongNameAuth.new),
          blockedUsersProvider.overrideWith((ref) async => blocked),
        ],
        child: MaterialApp(
          theme: TAppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: padding,
              textScaler: TextScaler.linear(textScale),
            ),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'profile keeps upgrade reachable with a long name and large text',
    (tester) async {
      await pumpScreen(tester, const ProfileScreen());
      expect(
        find.text(
          'A very long display name that should wrap inside a compact phone',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Upgrade to Pro'));
      expect(
        tester.getRect(find.text('Upgrade to Pro')).bottom,
        lessThanOrEqualTo(464),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'suspended account keeps acknowledgement reachable with large text',
    (tester) async {
      await pumpScreen(tester, const AccountSuspendedScreen());
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('OK'));
      expect(tester.getRect(find.text('OK')).bottom, lessThanOrEqualTo(464));
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('terms gate keeps account actions reachable with large text', (
    tester,
  ) async {
    await pumpScreen(tester, const TermsAcceptanceScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('I agree'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('settings retains scrollable options with large text', (
    tester,
  ) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked users keep unblock actions reachable with large text', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const BlockedUsersScreen(),
      blocked: const BlockedUsersResult(
        users: [BlockedUser(id: 'blocked', name: 'A long blocked user name')],
        anonymousBlockedCount: 3,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Unblock all'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile keeps its normal bottom button position', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const ProfileScreen(),
      size: const Size(393, 852),
      textScale: 1,
      padding: const EdgeInsets.only(top: 59, bottom: 34),
    );
    final button =
        find
            .ancestor(
              of: find.text('Upgrade to Pro'),
              matching: find.byType(Container),
            )
            .first;
    expect(tester.getRect(button).height, 58);
    expect(tester.getRect(button).top, closeTo(728, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('suspended account keeps its normal support button position', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const AccountSuspendedScreen(),
      size: const Size(393, 852),
      textScale: 1,
      padding: const EdgeInsets.only(top: 59, bottom: 34),
    );
    expect(tester.getRect(find.byType(GradientButton)).top, closeTo(690, 0.1));
    expect(tester.takeException(), isNull);
  });
}
