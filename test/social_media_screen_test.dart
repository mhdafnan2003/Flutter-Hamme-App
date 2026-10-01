import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/social_media_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSocialMedia(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SocialMediaScreen())),
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

  testWidgets('switches platform and fits a compact phone', (tester) async {
    await pumpSocialMedia(tester, size: const Size(320, 480));

    await tester.tap(find.text('snapchat'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Add your socials'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
