import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/matches/presentation/screens/match_reply_screen.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_success_overlay.dart';

import 'safety_test_fakes.dart';

void main() {
  Future<void> pumpReply(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 59, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: child!,
            ),
        home: MatchReplyScreen(
          match: testNamedMatch('match-1', userId: 'user-1', name: 'Ava'),
          currentUserImageUrl: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('places the match card, platform pill, and reply like Figma', (
    tester,
  ) async {
    await pumpReply(tester, const Size(393, 852));

    final avatars = tester.getRect(find.byType(MatchAvatarPair));
    final card = tester.getRect(find.byKey(const Key('match-reply-card')));
    final pill = tester.getRect(find.byKey(const Key('match-social-pill')));
    final button = tester.getRect(find.byKey(const Key('match-reply-button')));
    expect(avatars.topLeft, const Offset(84, 200));
    // The keyed inner card is inset by the 8 px outer border.
    expect(card.topLeft, const Offset(24, 266));
    expect(card.size, const Size(345, 209));
    expect(pill.left, closeTo(155, 0.5));
    expect(pill.top, 531);
    expect(pill.size, const Size(84, 38));
    expect(button.topLeft, const Offset(32, 585));
    expect(button.size, const Size(329, 62));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps match details usable on a compact phone', (tester) async {
    await pumpReply(tester, const Size(320, 640));

    expect(find.text('Reply'), findsOneWidget);
    expect(find.byKey(const Key('match-social-pill')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
