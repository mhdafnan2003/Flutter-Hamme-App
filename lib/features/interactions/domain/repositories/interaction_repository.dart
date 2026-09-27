import '../../../../models/interaction_result.dart';
import '../../../../models/interaction_record.dart';
import '../../../../models/interaction_type.dart';
import '../../../../models/match_record.dart';
import '../../../../models/vote_response.dart';

/// Voting and the vote/match feeds. Reporting, hiding and blocking live in
/// `SafetyRepository` (lib/features/safety).
abstract interface class InteractionRepository {
  Future<InteractionResult> sendInteraction({
    required String shareCode,
    required InteractionType type,
  });

  /// Also returns the card-limit status after this vote was counted.
  Future<VoteResponse> respondToInteraction({
    String? targetUserId,
    String? interactionId,
    required InteractionType type,
  });

  Future<List<MatchRecord>> getMatches();

  /// The Play queue by default; [history] returns every recent vote (Inbox).
  Future<List<InteractionRecord>> getReceivedInteractions({
    bool history = false,
  });
  Future<InteractionResult> finalizeInteraction(String token);
  Future<Map<String, dynamic>> getPendingInteraction(String token);
}
