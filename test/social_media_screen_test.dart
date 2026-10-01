import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/widgets/gradient_button.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/social_media_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSocialMedia(
    WidgetTester tester, {
    required Size size,
    bool keyboardOpen = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding:
                  keyboardOpen
                      ? const EdgeInsets.only(top: 59)
                      : EdgeInsets.zero,
              viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              viewInsets:
                  keyboardOpen
                      ? const EdgeInsets.only(bottom: 343)
                      : EdgeInsets.zero,
            ),
            child: const SocialMediaScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('matches the reference social media content', (tester) async {
    await pumpSocialMedia(tester, size: const Size(393, 852));

    expect(find.text('Add your socials'), findsOneWidget);
    expect(find.text('snapchat'), findsOneWidget);
    expect(find.text('instagram'), findsOneWidget);
    expect(find.text('@username'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).width, 345);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the keyboard-open Figma frame geometry', (tester) async {
    await pumpSocialMedia(
      tester,
      size: const Size(393, 852),
      keyboardOpen: true,
    );

    final progress = tester.getRect(
      find.byKey(const Key('onboarding-progress-track')),
    );
    expect(progress.left, closeTo(112, 0.5));
    expect(progress.top, closeTo(81, 0.5));
    expect(progress.width, 170);
    expect(progress.height, 9);
    expect(tester.getRect(find.text('Add your socials')).top, closeTo(130, 1));
    expect(tester.getRect(find.text('snapchat')).top, closeTo(204, 1));
    expect(tester.getRect(find.text('@username')).top, closeTo(287, 1));
    expect(tester.getRect(find.byType(GradientButton)).top, closeTo(429, 1));
    expect(tester.getRect(find.text('Skip')).top, closeTo(76, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches platform and fits a compact phone', (tester) async {
    await pumpSocialMedia(tester, size: const Size(320, 480));

    await tester.tap(find.text('snapchat'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Add your socials'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
