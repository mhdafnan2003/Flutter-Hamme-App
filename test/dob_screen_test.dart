import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/dob_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/widgets/age_picker_wheel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'));
    await font.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDobScreen(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
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
              textScaler: TextScaler.linear(textScale),
            ),
            child: const DobScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('matches the five-row Figma picker viewport', (tester) async {
    await pumpDobScreen(tester, size: const Size(393, 852));

    expect(find.text('What’s your age?'), findsOneWidget);
    expect(find.text('19'), findsNWidgets(2));
    expect(find.text('22'), findsNothing);
    expect(
      tester.getSize(find.byType(AgePickerWheel)).height,
      AgePickerWheel.wheelHeight,
    );
    expect(AgePickerWheel.wheelHeight, 175);
    expect(tester.takeException(), isNull);
  });

  testWidgets('age card and picker fit enlarged text', (tester) async {
    await pumpDobScreen(tester, size: const Size(320, 480), textScale: 2);
    final age = find.text('19').first;
    final card = find.ancestor(of: age, matching: find.byType(Container)).first;
    expect(
      tester.getRect(card).contains(tester.getRect(age).bottomRight),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a compact phone', (tester) async {
    await pumpDobScreen(tester, size: const Size(320, 480));

    expect(find.text('What’s your age?'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

