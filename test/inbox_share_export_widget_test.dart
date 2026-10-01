import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/features/inbox/presentation/widgets/inbox_share_export_widget.dart';

void main() {
  const variation = InboxVariation(
    gradientColors: [Color(0xFFCE58E6), Color(0xFFFE3B9D)],
    borderColor: Color(0xFFFF3C9E),
    emoji: '😍',
    typeKey: 'crush',
    tagline: 'Main character energy',
  );

  Future<void> pumpExport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InboxShareExportWidget(variation: variation, count: 156),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('matches the Figma composition on the 1080x1920 export', (
    tester,
  ) async {
    await pumpExport(tester, const Size(1080, 1920));

    final scale = 1920 / 852;
    final outer = tester.getRect(
      find.byKey(const Key('inbox-reaction-outer-card')),
    );
    final avatar = tester.getRect(
      find.byKey(const Key('inbox-reaction-avatar')),
    );
    final badge = tester.getRect(
      find.byKey(const Key('inbox-reaction-emoji-badge')),
    );
    final tagline = tester.getRect(
      find.byKey(const Key('inbox-reaction-tagline')),
    );

    expect(outer.width, closeTo(361 * scale, 0.1));
    expect(outer.height, closeTo(225 * scale, 0.1));
    expect(outer.top, closeTo(278 * scale, 0.1));
    expect(outer.center.dx, closeTo(540, 0.1));
    expect(avatar.width, closeTo(116 * scale, 0.1));
    expect(avatar.top, closeTo(220 * scale, 0.1));
    expect(badge.top, closeTo(310 * scale, 0.1));
    expect(tagline.top, closeTo(441 * scale, 0.1));
    expect(find.text('156 people have Crush on you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches native Figma dimensions at 393x852', (tester) async {
    await pumpExport(tester, const Size(393, 852));

    final outer = tester.getRect(
      find.byKey(const Key('inbox-reaction-outer-card')),
    );
    final avatar = tester.getRect(
      find.byKey(const Key('inbox-reaction-avatar')),
    );
    final badge = tester.getRect(
      find.byKey(const Key('inbox-reaction-emoji-badge')),
    );
    final tagline = tester.getRect(
      find.byKey(const Key('inbox-reaction-tagline')),
    );

    expect(outer, const Rect.fromLTWH(16, 278, 361, 225));
    expect(avatar.top, 220);
    expect(badge.top, 310);
    expect(tagline.top, 441);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scales uniformly into a narrower capture viewport', (
    tester,
  ) async {
    await pumpExport(tester, const Size(720, 1600));

    final outer = tester.getRect(
      find.byKey(const Key('inbox-reaction-outer-card')),
    );
    final avatar = tester.getRect(
      find.byKey(const Key('inbox-reaction-avatar')),
    );
    final tagline = tester.getRect(
      find.byKey(const Key('inbox-reaction-tagline')),
    );

    expect(outer.left, greaterThanOrEqualTo(0));
    expect(outer.right, lessThanOrEqualTo(720));
    expect(avatar.center.dx, closeTo(360, 1));
    expect(tagline.bottom, lessThan(1600));
    expect(tester.takeException(), isNull);
  });
}
