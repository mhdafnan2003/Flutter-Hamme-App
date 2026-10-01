import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';

class _SignedOutAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

void main() {
  Future<void> pumpSplash(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
  }

  testWidgets('centers the Figma wordmark on the reference frame', (
    tester,
  ) async {
    await pumpSplash(tester, const Size(393, 852));

    final rect = tester.getRect(find.byKey(const Key('splash-wordmark')));
    expect(rect.size, const Size(176, 65));
    expect(rect.center, const Offset(196.5, 426));
    expect(find.text('Hamme'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers the wordmark on a narrow phone', (tester) async {
    await pumpSplash(tester, const Size(320, 640));

    final rect = tester.getRect(find.byKey(const Key('splash-wordmark')));
    expect(rect.center, const Offset(160, 320));
    expect(tester.takeException(), isNull);
  });
}
