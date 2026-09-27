import '../../../../core/services/api_service.dart';
import '../../../../models/interaction_result.dart';
import '../../../../models/interaction_record.dart';
import '../../../../models/interaction_type.dart';
import '../../../../models/match_record.dart';
import '../../../../models/play_limit_status.dart';
import '../../../../models/vote_response.dart';

class InteractionRemoteDataSource {
  InteractionRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<InteractionResult> sendInteraction({
    required String shareCode,
    required InteractionType type,
  }) async {
    final response =
        await _apiService.post(
              '/interactions',
              authenticated: true,
              body: {'shareCode': shareCode, 'type': type.name},
            )
            as Map<String, dynamic>;

    return InteractionResult.fromJson(response);
  }

  Future<VoteResponse> respondToInteraction({
    String? targetUserId,
    String? interactionId,
    required InteractionType type,
  }) async {
    assert(
      (targetUserId == null) != (interactionId == null),
      'Exactly one response target is required.',
    );
    final response =
        await _apiService.post(
              '/interactions/respond',
              authenticated: true,
              body: {
                if (targetUserId != null) 'targetUserId': targetUserId,
                if (interactionId != null) 'interactionId': interactionId,
                'type': type.name,
              },
            )
            as Map<String, dynamic>;

    final statusJson = response['cardLimitStatus'];
    return (
      result: InteractionResult.fromJson(response),
      cardLimitStatus:
          statusJson is Map<String, dynamic>
              ? PlayLimitStatus.fromJson(statusJson)
              : null,
    );
  }

  Future<List<MatchRecord>> getMatches() async {
    final response =
        await _apiService.get('/interactions/matches', authenticated: true)
            as Map<String, dynamic>;

    final matches = response['matches'] as List<dynamic>? ?? <dynamic>[];
    return matches
        .cast<Map<String, dynamic>>()
        .map(MatchRecord.fromJson)
        .toList();
  }

  /// The Play queue (votes still waiting for an answer), or with [history]
  /// every recent vote, answered and anonymous ones included (Inbox).
  Future<List<InteractionRecord>> getReceivedInteractions({
    bool history = false,
  }) async {
    final response =
        await _apiService.get(
              history
                  ? '/interactions/received?scope=all'
                  : '/interactions/received',
              authenticated: true,
            )
            as Map<String, dynamic>;

    final interactions =
        response['interactions'] as List<dynamic>? ?? <dynamic>[];
    return interactions
        .cast<Map<String, dynamic>>()
        .map(InteractionRecord.fromJson)
        .toList();
  }

  Future<InteractionResult> finalizeInteraction(String token) async {
    final response =
        await _apiService.post(
              '/interactions/finalize',
              authenticated: true,
              body: {'token': token},
            )
            as Map<String, dynamic>;

    return InteractionResult.fromJson(response);
  }

  Future<Map<String, dynamic>> getPendingInteraction(String token) async {
    final response =
        await _apiService.get(
              '/interactions/pending/$token',
              authenticated: false,
            )
            as Map<String, dynamic>;

    return response;
  }
}
