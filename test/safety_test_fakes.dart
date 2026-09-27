import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/features/safety/domain/models/blocked_users.dart';
import 'package:hamme_app/features/safety/domain/models/report_reason.dart';
import 'package:hamme_app/features/safety/domain/models/report_result.dart';
import 'package:hamme_app/features/safety/domain/repositories/safety_repository.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/safety_providers.dart';

// Shared by the safety_*_test.dart files.

InteractionRecord testVote(String id, {String? from, bool anonymous = false}) {
  return InteractionRecord(
    id: id,
    fromUser: anonymous ? '' : from,
    fromUserName: anonymous || from == null ? null : 'Voter $from',
    toUser: 'me',
    type: InteractionType.crush,
    metadata:
        anonymous
            ? {'anonymous': true, 'anonymousVoteBackEnabled': true}
            : null,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  );
}

MatchRecord testNamedMatch(
  String id, {
  required String userId,
  String name = 'Sam',
}) {
  return MatchRecord(
    id: id,
    type: InteractionType.friend,
    matchedUser: AppUser(
      id: userId,
      name: name,
      email: '',
      instagramId: 'sam',
      shareCode: 'sam1',
    ),
    createdAt: DateTime.now(),
  );
}

MatchRecord testAnonymousMatch(String interactionId) {
  return MatchRecord(
    id: 'anonymous:$interactionId',
    type: InteractionType.friend,
    anonymous: true,
    matchedUser: AppUser(
      id: 'anonymous:$interactionId',
      name: 'Anonymous',
      email: '',
      instagramId: '',
      shareCode: '',
    ),
    createdAt: DateTime.now(),
  );
}

class SignedOutAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

/// Serves [votes] and [matches] as the server feeds and routes safety calls
/// to [repository], without touching auth storage or the network.
List<Override> testSafetyOverrides({
  required FakeSafetyRepository repository,
  List<InteractionRecord> votes = const [],
  List<MatchRecord> matches = const [],
}) {
  return [
    authControllerProvider.overrideWith(SignedOutAuthController.new),
    receivedInteractionsProvider.overrideWith((ref) async => votes),
    inboxInteractionsProvider.overrideWith((ref) async => votes),
    matchesProvider.overrideWith((ref) async => matches),
    safetyRepositoryProvider.overrideWithValue(repository),
  ];
}

/// Records every call as "method:args". Set [gate] to hold responses until it
/// completes, and [error] to make calls fail.
class FakeSafetyRepository implements SafetyRepository {
  final List<String> calls = [];
  Completer<void>? gate;
  Object? error;
  String? lastDetails;
  BlockedUsersResult blockedUsers = const BlockedUsersResult();

  Future<void> _call(String call) async {
    calls.add(call);
    final gate = this.gate;
    if (gate != null) await gate.future;
    final error = this.error;
    if (error != null) throw error;
  }

  @override
  Future<void> hideInteraction(String interactionId) =>
      _call('hide:$interactionId');

  @override
  Future<bool> blockInteractionSender(String interactionId) async {
    await _call('blockInteractionSender:$interactionId');
    return true;
  }

  @override
  Future<ReportResult> reportInteraction(
    String interactionId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  }) async {
    lastDetails = details;
    await _call('reportInteraction:$interactionId:${reason?.apiValue}:$block');
    return ReportResult(reportId: 'report-1', hidden: true, blocked: block);
  }

  @override
  Future<ReportResult> reportUser(
    String userId, {
    ReportReason? reason,
    String? details,
    bool block = true,
  }) async {
    lastDetails = details;
    await _call('reportUser:$userId:${reason?.apiValue}:$block');
    return ReportResult(reportId: 'report-1', blocked: block);
  }

  @override
  Future<void> blockUser(String userId) => _call('blockUser:$userId');

  @override
  Future<BlockedUsersResult> getBlockedUsers() async {
    await _call('getBlockedUsers');
    return blockedUsers;
  }

  @override
  Future<void> unblockUser(String userId) => _call('unblockUser:$userId');

  @override
  Future<int> clearAnonymousBlocks() async {
    await _call('clearAnonymousBlocks');
    return blockedUsers.anonymousBlockedCount;
  }
}
