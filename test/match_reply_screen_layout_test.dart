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
    expect(avatars.left, closeTo(84, 0.1));
    expect(avatars.top, closeTo(200, 0.1));
    // The keyed inner card is inset by the 8 px outer border.
    expect(card.left, closeTo(24, 0.1));
    expect(card.top, closeTo(266, 0.1));
    expect(card.width, closeTo(345, 0.1));
    expect(card.height, closeTo(209, 0.1));
    expect(pill.left, closeTo(155, 0.5));
    expect(pill.top, closeTo(531, 0.1));
    expect(pill.width, closeTo(84, 0.1));
    expect(pill.height, closeTo(38, 0.1));
    expect(button.left, closeTo(32, 0.1));
    expect(button.top, closeTo(585, 0.1));
    expect(button.width, closeTo(329, 0.1));
    expect(button.height, closeTo(62, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps match details usable on a compact phone', (tester) async {
    await pumpReply(tester, const Size(320, 640));

    expect(find.text('Reply'), findsOneWidget);
    expect(find.byKey(const Key('match-social-pill')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
