import 'package:flutter/foundation.dart';

import '../../../../models/interaction_record.dart';
import '../../../../models/match_record.dart';

/// Whether [interaction] is shown to the recipient as an anonymous vote.
bool isAnonymousInteraction(InteractionRecord interaction) =>
    interaction.metadata?['anonymous'] == true;

const String _anonymousMatchPrefix = 'anonymous:';

/// The vote behind an anonymous match. The API gives anonymous matches the id
/// `anonymous:<interactionId>` because they are never stored as a match.
String anonymousMatchInteractionId(MatchRecord match) {
  final id = match.id;
  return id.startsWith(_anonymousMatchPrefix)
      ? id.substring(_anonymousMatchPrefix.length)
      : id;
}

/// A received vote or a match the user can hide, report or block.
///
/// Anonymous targets never keep the sender's identity — not even a user id
/// the backend may have attached to the vote — so nothing the app shows or
/// sends while acting on them can hint at who voted. They are reported and
/// blocked through the vote instead.
@immutable
class SafetyTarget {
  const SafetyTarget._({
    required this.anonymous,
    this.interactionId,
    this.userId,
    this.matchId,
    this.name,
  });

  /// A vote on a Play card or in the Inbox.
  factory SafetyTarget.vote(InteractionRecord interaction) {
    final anonymous = isAnonymousInteraction(interaction);
    final senderId = interaction.fromUser?.trim() ?? '';
    return SafetyTarget._(
      anonymous: anonymous,
      interactionId: interaction.id,
      userId: anonymous || senderId.isEmpty ? null : senderId,
      name:
          anonymous
              ? null
              : _firstNonEmpty([
                interaction.fromUserName,
                interaction.fromUserUsername,
              ]),
    );
  }

  /// A match in the Matches list or on the match reply screen. Named matches
  /// are acted on through the other person's profile; anonymous ones through
  /// the vote they came from.
  factory SafetyTarget.match(MatchRecord match) {
    if (match.anonymous) {
      return SafetyTarget._(
        anonymous: true,
        interactionId: anonymousMatchInteractionId(match),
        matchId: match.id,
      );
    }
    return SafetyTarget._(
      anonymous: false,
      userId: match.matchedUser.id,
      matchId: match.id,
      name: _firstNonEmpty([match.matchedUser.name]),
    );
  }

  final bool anonymous;

  /// The vote to hide or report. Set for votes and anonymous matches.
  final String? interactionId;

  /// The named person behind the target. Always null when [anonymous].
  final String? userId;

  /// The match row showing this target, if any.
  final String? matchId;

  /// Display name of a named person. Always null when [anonymous].
  final String? name;

  /// Only a vote can be hidden without reporting it.
  bool get canHide => interactionId != null;

  /// How copy refers to the other person: "this anonymous voter" or a name,
  /// as in "Block Sam?".
  String get subject =>
      anonymous ? 'this anonymous voter' : name ?? 'this person';
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
