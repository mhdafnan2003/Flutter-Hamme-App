import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/providers/interaction_providers.dart';

void main() {
  InteractionRecord anonymousInteraction({
    required bool enabled,
    bool responded = false,
  }) {
    return InteractionRecord(
      id: '507f1f77bcf86cd799439011',
      toUser: '507f191e810c19729de860ea',
      type: InteractionType.friend,
      metadata: {'anonymous': true, 'anonymousVoteBackEnabled': enabled},
      respondedByCurrentUser: responded,
      createdAt: DateTime.utc(2026, 8, 18),
    );
  }

  group('anonymous vote-back feature flag', () {
    test('anonymous vote stays count-only when disabled', () {
      expect(
        isActionablePlayInteraction(anonymousInteraction(enabled: false)),
        isFalse,
      );
    });

    test('anonymous vote enters the Play queue when enabled', () {
      expect(
        isActionablePlayInteraction(anonymousInteraction(enabled: true)),
        isTrue,
      );
    });

    test('answered anonymous vote leaves the Play queue', () {
      expect(
        isActionablePlayInteraction(
          anonymousInteraction(enabled: true, responded: true),
        ),
        isFalse,
      );
    });

    test('anonymous match marker is decoded from the API', () {
      final match = MatchRecord.fromJson({
        'id': 'anonymous:507f1f77bcf86cd799439011',
        'type': 'friend',
        'anonymous': true,
        'createdAt': '2026-08-18T00:00:00.000Z',
        'matchedUser': {
          'id': 'anonymous:507f1f77bcf86cd799439011',
          'name': 'Anonymous',
          'email': '',
          'instagramId': '',
          'avatarUrl': null,
          'shareCode': '',
          'isPro': false,
        },
      });

      expect(match.anonymous, isTrue);
      expect(match.matchedUser.instagramId, isEmpty);
    });
  });
}
