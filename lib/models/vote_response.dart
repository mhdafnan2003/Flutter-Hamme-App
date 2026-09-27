import 'interaction_result.dart';
import 'play_limit_status.dart';

/// The result of a vote plus the card-limit status the server computed after
/// counting it, so the app doesn't have to fetch the status again. Null when
/// the response carries none.
typedef VoteResponse = ({
  InteractionResult result,
  PlayLimitStatus? cardLimitStatus,
});
