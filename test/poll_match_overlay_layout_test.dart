import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/play/presentation/widgets/poll_match_overlay.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/features/safety/presentation/widgets/safety_menu_button.dart';
import 'safety_test_fakes.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final font in ['Nunito', 'SchibstedGrotesk']) {
        await (FontLoader(
          font == 'SchibstedGrotesk' ? 'Schibsted Grotesk' : font,
        )..addFont(
          rootBundle.load('assets/fonts/$font-VariableFont_wght.ttf'),
        )).load();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(key: const Key('capture'), child: child),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('poll missing handle Continue invokes its callback', (
    tester,
  ) async {
    var dismissed = 0;
    final match = testAnonymousMatch('missing').copyWith(anonymous: false);
    await pump(
      tester,
      PollMatchOverlay(
        match: match,
        currentUserImageUrl: null,
        onDismiss: () => dismissed++,
      ),
      const Size(320, 480),
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(dismissed, 1);
    expect(tester.takeException(), isNull);
    expect(find.byType(SafetyMenuButton), findsNothing);
  });
  for (final anonymous in [false, true]) {
    for (final size in [const Size(393, 852), const Size(320, 480)]) {
      testWidgets(
        'poll overlay dismiss and anonymous safety $anonymous at $size',
        (tester) async {
          var dismissed = 0;
          final match = testNamedMatch(
            'poll',
            userId: 'user',
            name: 'Ava',
          ).copyWith(anonymous: anonymous);
          await pump(
            tester,
            PollMatchOverlay(
              match: match,
              currentUserImageUrl: null,
              onDismiss: () => dismissed++,
            ),
            size,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(SafetyMenuButton), findsNothing);
          await tester.tap(find.byType(AppCloseCircleButton));
          await tester.pump();
          expect(dismissed, 1);
          if (anonymous) {
            expect(find.text('Reply'), findsNothing);
            expect(find.text('sam'), findsNothing);
            await tester.ensureVisible(find.text('Continue'));
            await tester.tap(find.text('Continue'));
            await tester.pump();
            expect(dismissed, 2);
          }
        },
      );
    }
  }
}
