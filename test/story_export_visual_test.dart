import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/home/presentation/screens/share_playing_screen.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';

void main() {
  testWidgets('renders the Figma story export at the 3x canvas size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: StoryExportWidget(draft: const OnboardingDraft())),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 1080 &&
            widget.constraints?.maxHeight == 1920,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 780 &&
            widget.constraints?.maxHeight == 144,
      ),
      findsNWidgets(3),
    );
    expect(find.text('What do you think of me?'), findsOneWidget);
    expect(find.text('Friend'), findsOneWidget);
    expect(find.text('Crush'), findsOneWidget);
    expect(find.text('Frenemy'), findsOneWidget);
    // 360x800 Figma composition fits uniformly into the 9:16 export.
    final friend = tester.getRect(find.text('Friend'));
    expect(friend.center.dx, greaterThan(540));
    expect(friend.top, closeTo(278 * 2.4, 2));
    expect(friend.height, closeTo(25 * 2.4, 0.1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryExportWidget(
          draft: const OnboardingDraft(),
          showBrandLink: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HAMME.LINK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
