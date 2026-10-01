import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/pro_screen.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBillingController extends BillingController {
  @override
  BillingState build() => const BillingState();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpProScreen(WidgetTester tester, {required Size size}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingControllerProvider.overrideWith(_FakeBillingController.new),
        ],
        child: const MaterialApp(home: ProScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('matches the reference Pro content and CTA size', (tester) async {
    await pumpProScreen(tester, size: const Size(393, 852));

    expect(find.text('Unlock Unlimited'), findsOneWidget);
    expect(find.text('Access '), findsOneWidget);
    expect(find.text('Unlimited Play'), findsOneWidget);
    expect(find.text('Unlimited Rewinds'), findsOneWidget);
    expect(find.text('Priority Profile'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text(r'pro renews for $6.99/wk'), findsOneWidget);
    expect(tester.getRect(find.text('Privacy')).bottom, lessThanOrEqualTo(852));
    expect(tester.getRect(find.text('Restore')).bottom, lessThanOrEqualTo(852));
    expect(tester.getRect(find.text('Terms')).bottom, lessThanOrEqualTo(852));
    expect(tester.getSize(find.byType(ElevatedButton)), const Size(345, 62));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps footer visible without scrolling on a shorter phone', (
    tester,
  ) async {
    await pumpProScreen(tester, size: const Size(393, 740));

    expect(tester.getRect(find.text('Privacy')).bottom, lessThanOrEqualTo(740));
    expect(tester.getRect(find.text('Restore')).bottom, lessThanOrEqualTo(740));
    expect(tester.getRect(find.text('Terms')).bottom, lessThanOrEqualTo(740));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses scrolling only on an extremely short viewport', (
    tester,
  ) async {
    await pumpProScreen(tester, size: const Size(320, 480));

    expect(find.text('Unlock Unlimited'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
