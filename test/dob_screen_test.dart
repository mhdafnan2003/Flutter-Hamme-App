import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/dob_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/widgets/age_picker_wheel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDobScreen(WidgetTester tester, {required Size size}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DobScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('matches the five-row Figma picker viewport', (tester) async {
    await pumpDobScreen(tester, size: const Size(393, 852));

    expect(find.text('What’s your age?'), findsOneWidget);
    expect(find.text('19'), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(AgePickerWheel)).height,
      AgePickerWheel.wheelHeight,
    );
    expect(AgePickerWheel.wheelHeight, 150);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a compact phone', (tester) async {
    await pumpDobScreen(tester, size: const Size(320, 480));

    expect(find.text('What’s your age?'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
