import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../features/safety/data/datasources/safety_remote_data_source.dart';
import '../features/safety/data/repositories/safety_repository_impl.dart';
import '../features/safety/domain/models/blocked_users.dart';
import '../features/safety/domain/models/report_reason.dart';
import '../features/safety/domain/models/report_result.dart';
import '../features/safety/domain/models/safety_target.dart';
import '../features/safety/domain/repositories/safety_repository.dart';
import 'api_providers.dart';
import 'interaction_providers.dart';

final safetyRemoteDataSourceProvider = Provider<SafetyRemoteDataSource>((ref) {
  return SafetyRemoteDataSource(ref.watch(apiServiceProvider));
});

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepositoryImpl(ref.watch(safetyRemoteDataSourceProvider));
});

/// People the user blocked, plus how many anonymous voters they blocked.
final blockedUsersProvider = FutureProvider.autoDispose<BlockedUsersResult>((
  ref,
) {
  return ref.watch(safetyRepositoryProvider).getBlockedUsers();
});

/// Hide, report and block. The single way the app reports anything.
final safetyControllerProvider = NotifierProvider<SafetyController, void>(
  SafetyController.new,
);

/// Runs the safety actions for a [SafetyTarget].
///
/// Removal is optimistic: the item leaves every feed (through
/// [safetyFilterProvider]) before the request is sent, and comes back if the
/// request fails so the user can retry. On success the local filter keeps it
/// out, so the vote and match lists are only refetched when the server
/// removes more than the filter can mirror — an anonymous voter's other votes
/// — or on unblock. Never touches the auth state.
///
/// A 404 means the vote or person is already gone, so the item stays removed
/// and [SafetyTargetGoneException] is thrown instead of the API error.
class SafetyController extends Notifier<void> {
  @override
  void build() {}

  SafetyRepository get _repository => ref.read(safetyRepositoryProvider);

  SafetyFilterNotifier get _filter => ref.read(safetyFilterProvider.notifier);

  /// Removes a received vote from the user's feeds without reporting it.
  Future<void> hide(SafetyTarget target) async {
    final interactionId = target.interactionId;
    if (interactionId == null) {
      throw ArgumentError.value(target, 'target', 'Only votes can be hidden');
    }
    await _removeOptimistically(
      [() => _filter.hideInteraction(interactionId)],
      () => _repository.hideInteraction(interactionId),
    );
  }

  /// Reports a vote (through the vote, so anonymous votes work too) or a named
  /// person's profile (matches). With [block], the sender can no longer vote
  /// for or match with the user.
  Future<ReportResult> report(
    SafetyTarget target, {
    required ReportReason reason,
    String? details,
    bool block = true,
  }) async {
    final interactionId = target.interactionId;
    final userId = target.userId;
    final matchId = target.matchId;

    VoidCallback? undoLocalBlock;
    final ReportResult result;
    if (interactionId != null) {
      result = await _removeOptimistically(
        [
          () => _filter.hideInteraction(interactionId),
          if (block && userId != null)
            () => undoLocalBlock = _filter.blockUser(userId),
        ],
        () => _repository.reportInteraction(
          interactionId,
          reason: reason,
          details: details,
          block: block,
        ),
        // Blocking an anonymous voter also hides their other votes, which
        // the local filter can't know about.
        refreshFeeds: block && userId == null,
        refreshBlockedUsers: block,
      );
    } else if (userId != null) {
      result = await _removeOptimistically(
        [
          // Reporting a profile doesn't hide anything on the server unless
          // the user also blocks; still take the match out for this session.
          if (matchId != null) () => _filter.hideMatch(matchId),
          if (block) () => undoLocalBlock = _filter.blockUser(userId),
        ],
        () => _repository.reportUser(
          userId,
          reason: reason,
          details: details,
          block: block,
        ),
        refreshBlockedUsers: block,
      );
    } else {
      throw ArgumentError.value(target, 'target', 'Nothing to report');
    }

    // The server couldn't block (e.g. an old anonymous vote with no session
    // to block), so stop filtering their other votes locally.
    if (block && !result.blocked) undoLocalBlock?.call();
    return result;
  }

  /// Blocks the sender. A named person is blocked through their profile. An
  /// anonymous voter can only be blocked through the vote they sent, which
  /// hides that vote too (no report is filed).
  Future<void> block(SafetyTarget target) async {
    final userId = target.userId;
    final interactionId = target.interactionId;
    if (userId != null) {
      await _removeOptimistically(
        [() => _filter.blockUser(userId)],
        () => _repository.blockUser(userId),
        refreshBlockedUsers: true,
      );
    } else if (interactionId != null) {
      await _removeOptimistically(
        [() => _filter.hideInteraction(interactionId)],
        () => _repository.blockInteractionSender(interactionId),
        // Blocking an anonymous voter also hides their other votes, which
        // the local filter can't know about.
        refreshFeeds: true,
        refreshBlockedUsers: true,
      );
    } else {
      throw ArgumentError.value(target, 'target', 'Nobody to block');
    }
  }

  Future<void> unblockUser(String userId) async {
    await _repository.unblockUser(userId);
    _filter.unblockUser(userId);
    // Their votes and matches may come back.
    _refresh(feeds: true, blockedUsers: true);
  }

  /// Unblocks every anonymous voter; returns how many were unblocked. Votes
  /// that were reported stay removed.
  Future<int> clearAnonymousBlocks() async {
    final cleared = await _repository.clearAnonymousBlocks();
    _refresh(feeds: false, blockedUsers: true);
    return cleared;
  }

  Future<T> _removeOptimistically<T>(
    List<VoidCallback Function()> localChanges,
    Future<T> Function() request, {
    bool refreshFeeds = false,
    bool refreshBlockedUsers = false,
  }) async {
    final undos = [for (final apply in localChanges) apply()];
    final T result;
    try {
      result = await request();
    } on AppException catch (error) {
      if (error.statusCode == 404) throw const SafetyTargetGoneException();
      _undo(undos);
      rethrow;
    } catch (_) {
      _undo(undos);
      rethrow;
    }
    // Keep the local changes: they hold the item out of every list until the
    // lists next refresh on their own, including a fetch already in flight.
    _refresh(feeds: refreshFeeds, blockedUsers: refreshBlockedUsers);
    return result;
  }

  void _undo(List<VoidCallback> undos) {
    for (final undo in undos.reversed) {
      undo();
    }
  }

  void _refresh({required bool feeds, required bool blockedUsers}) {
    if (feeds) {
      _refreshIfLoaded(receivedInteractionsProvider);
      _refreshIfLoaded(inboxInteractionsProvider);
      _refreshIfLoaded(matchesProvider);
    }
    if (blockedUsers) _refreshIfLoaded(blockedUsersProvider);
  }

  // A list that isn't loaded fetches fresh data when it's next shown anyway,
  // and invalidating it would load it now (debug builds initialize the target
  // to check dependencies).
  void _refreshIfLoaded(ProviderBase<Object?> provider) {
    if (ref.exists(provider)) ref.invalidate(provider);
  }
}
