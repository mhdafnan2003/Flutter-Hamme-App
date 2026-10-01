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

  Future<void> pumpProScreen(
    WidgetTester tester, {
    required Size size,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingControllerProvider.overrideWith(_FakeBillingController.new),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, padding: padding),
            child: const ProScreen(),
          ),
        ),
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
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      0,
    );
    expect(tester.getSize(find.byType(ElevatedButton)), const Size(345, 62));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps footer visible without scrolling on a shorter phone', (
    tester,
  ) async {
    await pumpProScreen(
      tester,
      size: const Size(393, 740),
      padding: const EdgeInsets.only(top: 59, bottom: 34),
    );

    expect(tester.getRect(find.text('Privacy')).bottom, lessThanOrEqualTo(740));
    expect(tester.getRect(find.text('Restore')).bottom, lessThanOrEqualTo(740));
    expect(tester.getRect(find.text('Terms')).bottom, lessThanOrEqualTo(740));
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps legal links pinned on an extremely short viewport', (
    tester,
  ) async {
    await pumpProScreen(
      tester,
      size: const Size(320, 480),
      padding: const EdgeInsets.only(top: 24, bottom: 16),
    );

    expect(find.text('Unlock Unlimited'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    final privacyBefore = tester.getRect(find.text('Privacy'));
    expect(privacyBefore.bottom, lessThanOrEqualTo(480));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Privacy')), privacyBefore);
    expect(tester.getRect(find.text('Terms')).bottom, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });
}
