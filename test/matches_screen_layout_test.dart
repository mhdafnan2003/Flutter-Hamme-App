import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/matches/presentation/screens/matches_screen.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'safety_test_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpMatches(
    WidgetTester tester,
    Size size, {
    List<MatchRecord> matches = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleMatchesProvider.overrideWith((ref) => AsyncData(matches)),
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
          home: const MatchesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('matches the empty title and skeleton positions', (tester) async {
    await pumpMatches(tester, const Size(393, 852));

    expect(
      tester.getRect(find.byKey(const Key('matches-empty-title'))).top,
      closeTo(214, 2),
    );
    final skeleton = tester.getRect(
      find.byKey(const Key('matches-skeleton-first')),
    );
    expect(skeleton.left, 48);
    expect(skeleton.top, closeTo(405, 2));
    expect(skeleton.size, const Size(297, 56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches populated row geometry', (tester) async {
    await pumpMatches(
      tester,
      const Size(393, 852),
      matches: [testNamedMatch('match-1', userId: 'user-1', name: 'Christina')],
    );

    final avatar = tester.getRect(find.byKey(const Key('match-avatar')));
    final close = tester.getRect(find.byKey(const Key('match-close')));
    expect(avatar.topLeft, const Offset(24, 141));
    expect(avatar.size, const Size(52, 52));
    expect(close.topLeft, const Offset(329, 147));
    expect(close.size, const Size(40, 40));
    expect(find.text('Christina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the empty state usable on a compact phone', (
    tester,
  ) async {
    await pumpMatches(tester, const Size(320, 640));

    expect(find.text('No matches yet '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
