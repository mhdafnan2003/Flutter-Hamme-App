import 'package:flutter/foundation.dart';

import '../../../../models/interaction_record.dart';
import '../../../../models/match_record.dart';
import 'safety_target.dart';

/// Votes, matches and people the user hid, reported or blocked on this device.
///
/// Applied on top of the server feeds so an item disappears from Play, Inbox
/// and Matches the moment the user acts, before the server confirms. Once the
/// server has it, the feeds exclude the item themselves.
@immutable
class SafetyFilter {
  const SafetyFilter({
    this.hiddenInteractionIds = const <String>{},
    this.hiddenMatchIds = const <String>{},
    this.blockedUserIds = const <String>{},
  });

  final Set<String> hiddenInteractionIds;
  final Set<String> hiddenMatchIds;
  final Set<String> blockedUserIds;

  bool allowsInteraction(InteractionRecord interaction) {
    if (hiddenInteractionIds.contains(interaction.id)) return false;
    // Anonymous votes are never tied to a blocked person locally — dropping
    // one along with someone's named votes would hint at who sent it.
    if (isAnonymousInteraction(interaction)) return true;
    final senderId = interaction.fromUser ?? '';
    return senderId.isEmpty || !blockedUserIds.contains(senderId);
  }

  bool allowsMatch(MatchRecord match) {
    if (hiddenMatchIds.contains(match.id)) return false;
    if (match.anonymous) {
      return !hiddenInteractionIds.contains(anonymousMatchInteractionId(match));
    }
    return !blockedUserIds.contains(match.matchedUser.id);
  }

  SafetyFilter copyWith({
    Set<String>? hiddenInteractionIds,
    Set<String>? hiddenMatchIds,
    Set<String>? blockedUserIds,
  }) {
    return SafetyFilter(
      hiddenInteractionIds: hiddenInteractionIds ?? this.hiddenInteractionIds,
      hiddenMatchIds: hiddenMatchIds ?? this.hiddenMatchIds,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }
}
