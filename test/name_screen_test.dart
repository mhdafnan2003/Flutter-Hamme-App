import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/name_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpNameScreen(WidgetTester tester, {required Size size}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NameScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('matches the reference screen content', (tester) async {
    await pumpNameScreen(tester, size: const Size(393, 852));

    expect(find.text('What’s your name?'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('you cannot change this later'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).width, 345);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a compact phone', (tester) async {
    await pumpNameScreen(tester, size: const Size(320, 480));

    expect(find.text('What’s your name?'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
