import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:hamme_app/features/matches/presentation/screens/matches_screen.dart';
import 'package:hamme_app/features/play/presentation/screens/play_screen.dart';
import 'package:hamme_app/features/safety/domain/models/blocked_users.dart';
import 'package:hamme_app/features/safety/presentation/screens/blocked_users_screen.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/models/play_limit_status.dart';
import 'package:hamme_app/providers/play_limit_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'safety_test_fakes.dart';

class _UnrestrictedPlayLimit extends PlayLimitStatusNotifier {
  @override
  Future<PlayLimitStatus> build() async => PlayLimitStatus.unrestricted;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required FakeSafetyRepository repository,
    List<InteractionRecord> votes = const [],
    List<MatchRecord> matches = const [],
  }) async {
    // A large phone. The test font draws every glyph a full em wide, so
    // existing one-line labels need the extra width.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSafetyOverrides(
            repository: repository,
            votes: votes,
            matches: matches,
          ),
          playLimitStatusProvider.overrideWith(_UnrestrictedPlayLimit.new),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    // Let the overridden feeds resolve. Anonymous cards animate forever, so
    // pump fixed durations rather than settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Lets transitions and the snack bar finish before the tree is torn down.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  }

  const anonymousCardControl = 'Report or block this anonymous voter';

  testWidgets('anonymous Play cards have a report control', (tester) async {
    await pumpScreen(
      tester,
      const PlayScreen(),
      repository: FakeSafetyRepository(),
      votes: [testVote('a1', anonymous: true)],
    );

    expect(find.byTooltip(anonymousCardControl), findsOneWidget);
    await finish(tester);
  });

  testWidgets('hiding a Play card shows the next vote before the server '
      'answers', (tester) async {
    final repository = FakeSafetyRepository()..gate = Completer<void>();
    await pumpScreen(
      tester,
      const PlayScreen(),
      repository: repository,
      votes: [testVote('a1', anonymous: true), testVote('v2', from: 'u2')],
    );

    await tester.tap(find.byTooltip(anonymousCardControl));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Hide this vote'), findsOneWidget);
    expect(find.text('Report…'), findsOneWidget);
    expect(find.text('Block…'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Hide this vote'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, ['hide:a1']);
    expect(find.byTooltip(anonymousCardControl), findsNothing);
    expect(find.byTooltip('Report or block Voter u2'), findsOneWidget);

    repository.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Vote hidden.'), findsOneWidget);
    await finish(tester);
  });

  Future<void> openReportSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip(anonymousCardControl));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Report…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('reporting an anonymous vote blocks by default and confirms', (
    tester,
  ) async {
    final repository = FakeSafetyRepository();
    await pumpScreen(
      tester,
      const PlayScreen(),
      repository: repository,
      votes: [testVote('a1', anonymous: true), testVote('v2', from: 'u2')],
    );

    await openReportSheet(tester);
    expect(
      find.text('Why are you reporting this anonymous voter?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Bullying or harassment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final blockSwitch = find.byType(SwitchListTile);
    expect(find.text('Also block this anonymous voter'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(blockSwitch).value, true);
    await tester.enterText(find.byType(TextField), 'Votes every hour');
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, ['reportInteraction:a1:harassment:true']);
    expect(repository.lastDetails, 'Votes every hour');
    expect(find.text('Report sent'), findsOneWidget);
    expect(
      find.textContaining(
        'Thanks for letting us know. Our team reviews every report within '
        '24 hours.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('They can no longer vote for you.'),
      findsOneWidget,
    );
    expect(find.byTooltip(anonymousCardControl), findsNothing);

    await tester.tap(find.text('OK'));
    await finish(tester);
  });

  testWidgets('a failed report brings the card back and can be retried', (
    tester,
  ) async {
    final repository =
        FakeSafetyRepository()..error = const AppException('No connection');
    await pumpScreen(
      tester,
      const PlayScreen(),
      repository: repository,
      votes: [testVote('a1', anonymous: true), testVote('v2', from: 'u2')],
    );

    await openReportSheet(tester);
    await tester.tap(find.text('Spam or scam'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("Your report wasn't sent. No connection"),
      findsOneWidget,
    );
    // The card came back behind the sheet.
    expect(find.byTooltip(anonymousCardControl), findsOneWidget);

    repository.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, [
      'reportInteraction:a1:spam:true',
      'reportInteraction:a1:spam:true',
    ]);
    expect(find.text('Report sent'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await finish(tester);
  });

  testWidgets('the Inbox lists anonymous and answered votes to act on', (
    tester,
  ) async {
    final repository = FakeSafetyRepository();
    // With anonymous vote-back off, this vote never reaches Play.
    final countOnlyAnonymous = testVote(
      'a1',
      anonymous: true,
    ).copyWith(metadata: {'anonymous': true});
    await pumpScreen(
      tester,
      const InboxScreen(),
      repository: repository,
      votes: [
        countOnlyAnonymous,
        testVote('v2', from: 'u2'),
        testVote('v3', from: 'u3').copyWith(respondedByCurrentUser: true),
      ],
    );

    expect(find.text('Anonymous voter'), findsOneWidget);
    expect(find.text('Voter u3'), findsOneWidget);
    // Still waiting in Play, where the voter is introduced.
    expect(find.text('Voter u2'), findsNothing);
    expect(find.text('1 more vote is waiting for you in Play.'), findsOneWidget);

    final rowMenu = find.byTooltip('Hide, report or block this anonymous vote');
    await tester.ensureVisible(rowMenu);
    await tester.pump();
    await tester.tap(rowMenu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Hide this vote'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, ['hide:a1']);
    expect(find.text('Anonymous voter'), findsNothing);
    await finish(tester);
  });

  testWidgets('a named match can be blocked from the Matches list', (
    tester,
  ) async {
    final repository = FakeSafetyRepository();
    await pumpScreen(
      tester,
      const MatchesScreen(),
      repository: repository,
      matches: [
        testNamedMatch('m1', userId: 'u1'),
        testNamedMatch('m2', userId: 'u2', name: 'Alex'),
      ],
    );
    expect(find.text('Sam'), findsOneWidget);

    await tester.tap(find.byTooltip('Report or block Sam'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // A match isn't a vote, so it can be reported or blocked but not hidden.
    expect(find.text('Hide this vote'), findsNothing);

    await tester.tap(find.text('Block…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Block Sam?'), findsOneWidget);

    await tester.tap(find.text('Block'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, ['blockUser:u1']);
    expect(find.text('Sam'), findsNothing);
    expect(find.text('Alex'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('blocked users and anonymous voters can be unblocked', (
    tester,
  ) async {
    final repository =
        FakeSafetyRepository()
          ..blockedUsers = const BlockedUsersResult(
            users: [BlockedUser(id: 'u1', name: 'Sam', username: 'sam')],
            anonymousBlockedCount: 2,
          );
    await pumpScreen(
      tester,
      const BlockedUsersScreen(),
      repository: repository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('@sam'), findsOneWidget);
    expect(find.text('2 anonymous voters blocked'), findsOneWidget);

    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(find.text('Unblock Sam?'), findsOneWidget);
    await tester.tap(find.text('Unblock').last);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('unblockUser:u1'));
    expect(find.text('Sam'), findsNothing);

    await tester.tap(find.text('Unblock all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock all').last);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('clearAnonymousBlocks'));
    expect(find.text('No one is blocked'), findsOneWidget);
    await finish(tester);
  });
}
