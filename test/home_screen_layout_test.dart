import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hamme_app/features/home/presentation/screens/home_screen.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'SHARE_LINK_BASE=https://example.test/poll',
    );
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    await tester.runAsync(() async {
      await (FontLoader('Nunito')..addFont(
        rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'),
      )).load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: child!,
              ),
          home: Scaffold(
            body: const HomeScreen(),
            bottomNavigationBar: HammeBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Figma home sections and two visible tabs', (
    tester,
  ) async {
    await pumpHome(tester, const Size(393, 852));

    expect(find.text('Step 1: Copy your link'), findsOneWidget);
    expect(find.text('Step 2: Share link to your story'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
    expect(tester.getCenter(find.text('Share')).dx, closeTo(113, 0.1));
    expect(tester.getCenter(find.text('Play')).dx, closeTo(285, 0.1));
    expect(find.bySemanticsLabel('Edit profile'), findsOneWidget);
    expect(find.text('Share!').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the Share action above navigation on a shorter phone', (
    tester,
  ) async {
    await pumpHome(tester, const Size(393, 740));

    final shareBottom = tester.getRect(find.text('Share!')).bottom;
    final navTop = tester.getRect(find.byType(HammeBottomNavBar)).top;
    expect(shareBottom, lessThan(navTop));
    expect(find.text('Share!').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the saved social handle without a duplicate prefix', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_name': 'Taylor',
      'onboarding_username': '@taylor',
    });
    await pumpHome(tester, const Size(393, 852));
    expect(find.text('@taylor'), findsOneWidget);
    expect(find.text('Taylor'), findsOneWidget);
    final name = tester.getRect(find.text('Taylor'));
    final handle = tester.getRect(find.text('@taylor'));
    expect(name.height, closeTo(27, 0.1));
    expect(handle.height, closeTo(16, 0.1));
    expect(handle.top, closeTo(name.bottom, 0.1));
    expect(tester.takeException(), isNull);
  });
}
