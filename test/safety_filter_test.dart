import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/features/safety/domain/models/report_reason.dart';
import 'package:hamme_app/features/safety/domain/models/report_result.dart';
import 'package:hamme_app/features/safety/domain/models/safety_filter.dart';
import 'package:hamme_app/features/safety/domain/models/safety_target.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/safety_providers.dart';

import 'safety_test_fakes.dart';

void main() {
  group('SafetyFilter', () {
    test('a hidden vote also hides the anonymous match made from it', () {
      const filter = SafetyFilter(hiddenInteractionIds: {'a1'});

      expect(filter.allowsInteraction(testVote('a1', anonymous: true)), false);
      expect(filter.allowsMatch(testAnonymousMatch('a1')), false);
      expect(filter.allowsMatch(testAnonymousMatch('a2')), true);
    });

    test('a blocked person loses their votes and matches', () {
      const filter = SafetyFilter(blockedUserIds: {'u1'});

      expect(filter.allowsInteraction(testVote('v1', from: 'u1')), false);
      expect(filter.allowsInteraction(testVote('v2', from: 'u2')), true);
      expect(filter.allowsMatch(testNamedMatch('m1', userId: 'u1')), false);
      expect(filter.allowsMatch(testNamedMatch('m2', userId: 'u2')), true);
    });

    test('blocking a person never drops an anonymous vote they sent', () {
      const filter = SafetyFilter(blockedUserIds: {'u1'});
      // Dropping it together with u1's named votes would reveal the sender.
      final attributed = testVote('a1', anonymous: true).copyWith(
        fromUser: 'u1',
      );

      expect(filter.allowsInteraction(attributed), true);
    });
  });

  group('SafetyTarget', () {
    test('an anonymous vote never carries who sent it', () {
      final target = SafetyTarget.vote(
        testVote(
          'a1',
          anonymous: true,
        ).copyWith(fromUser: 'u1', fromUserName: 'Sam'),
      );

      expect(target.anonymous, true);
      expect(target.interactionId, 'a1');
      expect(target.userId, isNull);
      expect(target.name, isNull);
      expect(target.subject, 'this anonymous voter');
      expect(target.canHide, true);
    });

    test('a named vote targets the vote and its sender', () {
      final target = SafetyTarget.vote(testVote('v1', from: 'u1'));

      expect(target.interactionId, 'v1');
      expect(target.userId, 'u1');
      expect(target.subject, 'Voter u1');
    });

    test('an anonymous match is acted on through the vote behind it', () {
      final target = SafetyTarget.match(testAnonymousMatch('abc123'));

      expect(target.anonymous, true);
      expect(target.interactionId, 'abc123');
      expect(target.userId, isNull);
      expect(target.canHide, true);
    });

    test('a named match is acted on through the other profile', () {
      final target = SafetyTarget.match(testNamedMatch('m1', userId: 'u1'));

      expect(target.interactionId, isNull);
      expect(target.userId, 'u1');
      expect(target.canHide, false);
      expect(target.subject, 'Sam');
    });
  });

  group('SafetyController', () {
    late FakeSafetyRepository repository;
    final namedVote = testVote('v1', from: 'u1');
    final anonymousVote = testVote('a1', anonymous: true);

    setUp(() => repository = FakeSafetyRepository());

    Future<ProviderContainer> containerWith(
      List<InteractionRecord> votes, {
      List<String> matchesFor = const [],
    }) async {
      final container = ProviderContainer(
        overrides: testSafetyOverrides(
          repository: repository,
          votes: votes,
          matches: [
            for (final id in matchesFor)
              id.startsWith('u')
                  ? testNamedMatch('m-$id', userId: id)
                  : testAnonymousMatch(id),
          ],
        ),
      );
      addTearDown(container.dispose);
      await container.read(receivedInteractionsProvider.future);
      await container.read(matchesProvider.future);
      return container;
    }

    List<String> playQueue(ProviderContainer container) => [
      for (final vote in container.read(pendingPlayInteractionsProvider).value!)
        vote.id,
    ];

    List<String> inbox(ProviderContainer container) => [
      for (final vote
          in container.read(visibleReceivedInteractionsProvider).value!)
        vote.id,
    ];

    List<String> matches(ProviderContainer container) => [
      for (final match in container.read(visibleMatchesProvider).value!)
        match.id,
    ];

    test('hiding removes the vote everywhere before the server answers', () async {
      final container = await containerWith([
        namedVote,
        anonymousVote,
      ], matchesFor: ['a1']);
      expect(playQueue(container), ['v1', 'a1']);
      expect(matches(container), ['anonymous:a1']);

      repository.gate = Completer<void>();
      final hiding = container
          .read(safetyControllerProvider.notifier)
          .hide(SafetyTarget.vote(anonymousVote));

      expect(repository.calls, ['hide:a1']);
      expect(playQueue(container), ['v1']);
      expect(inbox(container), ['v1']);
      expect(matches(container), isEmpty);

      repository.gate!.complete();
      await hiding;
      expect(playQueue(container), ['v1']);
    });

    test('a failed hide puts the vote back so it can be retried', () async {
      final container = await containerWith([namedVote, anonymousVote]);
      repository
        ..gate = Completer<void>()
        ..error = const AppException('Network down', statusCode: 503);

      final hiding = container
          .read(safetyControllerProvider.notifier)
          .hide(SafetyTarget.vote(anonymousVote));
      expect(playQueue(container), ['v1']);

      repository.gate!.complete();
      await expectLater(hiding, throwsA(isA<AppException>()));
      expect(playQueue(container), ['v1', 'a1']);
    });

    test('reporting with block removes the sender’s other votes and matches', () async {
      final otherVoteFromSender = testVote('v2', from: 'u1');
      final someoneElse = testVote('v3', from: 'u2');
      final container = await containerWith(
        [namedVote, otherVoteFromSender, someoneElse],
        matchesFor: ['u1', 'u2'],
      );

      final result = await container
          .read(safetyControllerProvider.notifier)
          .report(
            SafetyTarget.vote(namedVote),
            reason: ReportReason.harassment,
            details: 'Keeps sending these',
          );

      expect(result.blocked, true);
      expect(repository.calls, ['reportInteraction:v1:harassment:true']);
      expect(repository.lastDetails, 'Keeps sending these');
      expect(inbox(container), ['v3']);
      expect(matches(container), ['m-u2']);
    });

    test('reporting without block only removes the reported vote', () async {
      final otherVoteFromSender = testVote('v2', from: 'u1');
      final container = await containerWith([namedVote, otherVoteFromSender]);

      await container
          .read(safetyControllerProvider.notifier)
          .report(
            SafetyTarget.vote(namedVote),
            reason: ReportReason.spam,
            block: false,
          );

      expect(repository.calls, ['reportInteraction:v1:spam:false']);
      expect(inbox(container), ['v2']);
    });

    test('an anonymous voter is blocked through their vote', () async {
      final container = await containerWith([namedVote, anonymousVote]);

      await container
          .read(safetyControllerProvider.notifier)
          .block(SafetyTarget.vote(anonymousVote));

      // Blocking alone files no report.
      expect(repository.calls, ['blockInteractionSender:a1']);
      expect(inbox(container), ['v1']);
    });

    test('a named person is blocked through their profile', () async {
      final container = await containerWith([
        namedVote,
        anonymousVote,
      ], matchesFor: ['u1']);

      await container
          .read(safetyControllerProvider.notifier)
          .block(SafetyTarget.vote(namedVote));

      expect(repository.calls, ['blockUser:u1']);
      expect(inbox(container), ['a1']);
      expect(matches(container), isEmpty);
    });

    test('a vote that is already gone stays removed', () async {
      final container = await containerWith([namedVote, anonymousVote]);
      repository.error = const AppException('Not found.', statusCode: 404);

      await expectLater(
        container
            .read(safetyControllerProvider.notifier)
            .hide(SafetyTarget.vote(anonymousVote)),
        throwsA(isA<SafetyTargetGoneException>()),
      );
      expect(playQueue(container), ['v1']);
    });

    test('unblocking brings the person’s votes back', () async {
      final container = await containerWith([namedVote]);
      final controller = container.read(safetyControllerProvider.notifier);

      await controller.block(SafetyTarget.vote(namedVote));
      expect(inbox(container), isEmpty);

      await controller.unblockUser('u1');
      await container.read(receivedInteractionsProvider.future);
      expect(repository.calls, ['blockUser:u1', 'unblockUser:u1']);
      expect(inbox(container), ['v1']);
    });
  });
}
