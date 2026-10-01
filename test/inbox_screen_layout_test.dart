import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'safety_test_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpInbox(
    WidgetTester tester,
    Size size, {
    List<InteractionRecord> votes = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleInboxInteractionsProvider.overrideWith(
            (ref) => AsyncData(votes),
          ),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: child!,
              ),
          home: Scaffold(
            body: const InboxScreen(),
            bottomNavigationBar: HammeBottomNavBar(
              currentIndex: 2,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('matches empty Inbox card and hint positions', (tester) async {
    await pumpInbox(tester, const Size(393, 852));

    final card = tester.getRect(
      find.byKey(const Key('inbox-reaction-outer-card')).first,
    );
    expect(card.left, closeTo(16, 0.1));
    expect(card.top, closeTo(268, 2));
    expect(card.width, closeTo(361, 0.1));
    expect(card.height, 225);
    expect(
      tester.getRect(find.text('Numbers fill up the moment someone').first).top,
      closeTo(409, 2),
    );
    expect(find.text('Inbox'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves a populated card up and keeps Share visible', (
    tester,
  ) async {
    await pumpInbox(
      tester,
      const Size(393, 740),
      votes: [testVote('vote-1', from: 'user-1')],
    );

    final card = tester.getRect(
      find.byKey(const Key('inbox-reaction-outer-card')).first,
    );
    final share = tester.getRect(find.byType(ElevatedButton));
    final nav = tester.getRect(find.byType(HammeBottomNavBar));
    expect(card.top, closeTo(240, 2));
    expect(share.left, closeTo(32, 0.1));
    expect(share.top, closeTo(587, 2));
    expect(share.size, const Size(329, 62));
    expect(share.bottom, lessThan(nav.top));
    final adjacentCard = tester.getRect(
      find.byKey(const Key('inbox-reaction-outer-card')).at(1),
    );
    expect(adjacentCard.left, closeTo(385, 1));
    expect(find.text('Share').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the Figma Friend and Frenemy captions', (tester) async {
    await pumpInbox(
      tester,
      const Size(393, 852),
      votes: [
        testVote(
          'friend',
          from: 'friend-user',
        ).copyWith(type: InteractionType.friend),
        testVote(
          'frenemy',
          from: 'frenemy-user',
        ).copyWith(type: InteractionType.frenemy),
      ],
    );

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 person wants to be your Friend'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 person is your Frenemy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
