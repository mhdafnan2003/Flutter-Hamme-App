import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/matches/presentation/screens/match_reply_screen.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_success_overlay.dart';

import 'safety_test_fakes.dart';

void main() {
  Future<void> pumpReply(
    WidgetTester tester,
    Size size, {
    MatchRecord? match,
    double scale = 1,
  }) async {
    await tester.runAsync(() async {
      await (FontLoader('Nunito')..addFont(
        rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'),
      )).load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 59, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: child!,
            ),
        home: MatchReplyScreen(
          match:
              match ?? testNamedMatch('match-1', userId: 'user-1', name: 'Ava'),
          currentUserImageUrl: null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('places the match card, platform pill, and reply like Figma', (
    tester,
  ) async {
    await pumpReply(tester, const Size(393, 852));

    final avatars = tester.getRect(find.byType(MatchAvatarPair));
    final card = tester.getRect(find.byKey(const Key('match-reply-card')));
    final pill = tester.getRect(find.byKey(const Key('match-social-pill')));
    final button = tester.getRect(find.byKey(const Key('match-reply-button')));
    expect(
      tester.getRect(find.byType(AppCloseCircleButton)).topLeft,
      const Offset(333, 78),
    );
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
  testWidgets('switches Reply platform only when a profile is available', (
    tester,
  ) async {
    final base = testNamedMatch('m1', userId: 'u1');
    await pumpReply(
      tester,
      const Size(393, 852),
      match: base.copyWith(
        matchedUser: base.matchedUser.copyWith(snapchatId: 'sam_snap'),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Reply on Snapchat'));
    await tester.pump();
    var icon = tester.widget<Image>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Image),
      ),
    );
    expect(icon.image, const AssetImage('assets/icons/snap-fill.png'));
    await tester.tap(find.bySemanticsLabel('Reply on Instagram'));
    await tester.pump();
    icon = tester.widget<Image>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Image),
      ),
    );
    expect(icon.image, const AssetImage('assets/icons/insta-outline.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not select an unavailable social profile', (tester) async {
    await pumpReply(tester, const Size(393, 852));
    await tester.tap(find.bySemanticsLabel('Reply on Snapchat'));
    await tester.pump();
    final icon = tester.widget<Image>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Image),
      ),
    );
    expect(icon.image, const AssetImage('assets/icons/insta-outline.png'));
  });

  testWidgets('keeps anonymous profiles hidden and offers no Reply', (
    tester,
  ) async {
    await pumpReply(
      tester,
      const Size(320, 480),
      match: testAnonymousMatch('a1'),
      scale: 1.5,
    );
    expect(find.byKey(const Key('match-social-pill')), findsNothing);
    expect(find.text('Reply'), findsNothing);
    expect(find.byType(AppCloseCircleButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close stays tappable above scrolling content on short phones', (
    tester,
  ) async {
    await pumpReply(tester, const Size(320, 480), scale: 1.5);
    expect(find.byType(AppCloseCircleButton).hitTestable(), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppCloseCircleButton).hitTestable(), findsOneWidget);
    expect(find.text('Reply').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('falls back after available social handles change', (
    tester,
  ) async {
    final base = testNamedMatch('m1', userId: 'u1');
    await pumpReply(
      tester,
      const Size(393, 852),
      match: base.copyWith(
        matchedUser: base.matchedUser.copyWith(snapchatId: 'sam_snap'),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Reply on Snapchat'));
    await tester.pump();
    await pumpReply(tester, const Size(393, 852), match: base);
    final icon = tester.widget<Image>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Image),
      ),
    );
    expect(icon.image, const AssetImage('assets/icons/insta-outline.png'));
  });

  testWidgets('empty Instagram handle falls back to registered Snapchat', (
    tester,
  ) async {
    final base = testNamedMatch('m1', userId: 'u1');
    await pumpReply(
      tester,
      const Size(393, 852),
      match: base.copyWith(
        matchedUser: base.matchedUser.copyWith(
          instagramId: ' @ ',
          snapchatId: 'sam_snap',
        ),
      ),
    );
    final icon = tester.widget<Image>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Image),
      ),
    );
    expect(icon.image, const AssetImage('assets/icons/snap-fill.png'));
  });
  testWidgets('anonymous Reply matches its distinct Figma card position', (
    tester,
  ) async {
    await pumpReply(
      tester,
      const Size(393, 852),
      match: testAnonymousMatch('a1'),
    );
    expect(tester.getRect(find.byType(MatchAvatarPair)).top, closeTo(248, 0.1));
    expect(find.text('Reply'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
