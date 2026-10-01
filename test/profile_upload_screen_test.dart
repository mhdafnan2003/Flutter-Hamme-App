import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/profile_upload_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/widgets/profile_avatar_stack.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpProfileUpload(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileUploadScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('matches the reference profile upload content', (tester) async {
    await pumpProfileUpload(tester, size: const Size(393, 852));

    expect(find.text('Set your profile pic'), findsOneWidget);
    expect(find.text('USE A RECENT PHOTO'), findsOneWidget);
    expect(find.text('CLEARLY SHOW YOUR FACE'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(ProfileAvatarStack), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a compact phone', (tester) async {
    await pumpProfileUpload(tester, size: const Size(320, 480));

    expect(find.text('Set your profile pic'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
