import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../features/interactions/data/datasources/interaction_remote_data_source.dart';
import '../features/interactions/data/repositories/interaction_repository_impl.dart';
import '../features/interactions/domain/repositories/interaction_repository.dart';
import '../features/safety/domain/models/safety_filter.dart';
import '../models/interaction_result.dart';
import '../models/interaction_record.dart';
import '../models/interaction_type.dart';
import '../models/match_record.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import 'deferred_interaction_provider.dart';
import 'onboarding_providers.dart';

final interactionRemoteDataSourceProvider =
    Provider<InteractionRemoteDataSource>((ref) {
      return InteractionRemoteDataSource(ref.watch(apiServiceProvider));
    });

final interactionRepositoryProvider = Provider<InteractionRepository>((ref) {
  return InteractionRepositoryImpl(
    ref.watch(interactionRemoteDataSourceProvider),
  );
});

/// Server matches from the last 24 hours. Invalidate this to refetch; show
/// [visibleMatchesProvider] so hidden, reported and blocked matches stay out.
final matchesProvider = FutureProvider<List<MatchRecord>>((ref) async {
  // Only a change of account changes the feed. Watching the whole session
  // refetched this on every session write (app resume, profile edits).
  final userId = await ref.watch(
    authControllerProvider.selectAsync((session) => session?.user.id),
  );
  if (userId == null) {
    throw const AppException('You need to sign in to view matches.');
  }
  final allMatches =
      await ref.watch(interactionRepositoryProvider).getMatches();
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  return allMatches.where((m) => m.createdAt.isAfter(cutoff)).toList();
});

/// Every vote the server returns for the user. Invalidate this to refetch;
/// show [visibleReceivedInteractionsProvider] so hidden, reported and blocked
/// votes stay out.
final receivedInteractionsProvider = FutureProvider<List<InteractionRecord>>((
  ref,
) async {
  debugPrint('[Inbox] fetch start');
  // Only a change of account changes the feed (see matchesProvider).
  final userId = await ref.watch(
    authControllerProvider.selectAsync((session) => session?.user.id),
  );
  if (userId == null) {
    debugPrint('[Inbox] skipped fetch: no auth token');
    throw const AppException('You need to sign in to view interactions.');
  }

  final items =
      await ref.watch(interactionRepositoryProvider).getReceivedInteractions();
  debugPrint('[Inbox] API success');
  debugPrint('[Inbox] interactions received=${items.length}');

  int crush = 0, friend = 0, frenemy = 0;
  for (final item in items) {
    if (item.type.name == 'crush') crush++;
    if (item.type.name == 'friend') friend++;
    if (item.type.name == 'frenemy' || item.type.name == 'ameny') frenemy++;
  }
  debugPrint('[Inbox] crushCount=$crush');
  debugPrint('[Inbox] friendCount=$friend');
  debugPrint('[Inbox] frenemyCount=$frenemy');

  return items;
});

bool isActionablePlayInteraction(InteractionRecord item) {
  final hasRegisteredVoter = item.fromUser != null && item.fromUser!.isNotEmpty;
  final anonymousVoteBackEnabled =
      item.metadata?['anonymous'] == true &&
      item.metadata?['anonymousVoteBackEnabled'] == true;
  return (hasRegisteredVoter || anonymousVoteBackEnabled) &&
      !item.respondedByCurrentUser;
}

/// Votes, matches and people the user hid, reported or blocked on this device
/// (see [SafetyFilter]). Laid over the server feeds below so an item leaves
/// Play, Inbox and Matches at once, before the server confirms. Resets when
/// the signed-in account changes; the server keeps the lasting record.
final safetyFilterProvider =
    NotifierProvider<SafetyFilterNotifier, SafetyFilter>(
      SafetyFilterNotifier.new,
    );

class SafetyFilterNotifier extends Notifier<SafetyFilter> {
  @override
  SafetyFilter build() {
    ref.watch(
      authControllerProvider.select((auth) => auth.valueOrNull?.user.id),
    );
    return const SafetyFilter();
  }

  // Each change returns a callback that reverts exactly that change, so a
  // failed request can put the item back without undoing an earlier action.

  VoidCallback hideInteraction(String interactionId) {
    if (state.hiddenInteractionIds.contains(interactionId)) return _noop;
    state = state.copyWith(
      hiddenInteractionIds: {...state.hiddenInteractionIds, interactionId},
    );
    return () => state = state.copyWith(
      hiddenInteractionIds: {...state.hiddenInteractionIds}
        ..remove(interactionId),
    );
  }

  VoidCallback hideMatch(String matchId) {
    if (state.hiddenMatchIds.contains(matchId)) return _noop;
    state = state.copyWith(hiddenMatchIds: {...state.hiddenMatchIds, matchId});
    return () => state = state.copyWith(
      hiddenMatchIds: {...state.hiddenMatchIds}..remove(matchId),
    );
  }

  VoidCallback blockUser(String userId) {
    if (state.blockedUserIds.contains(userId)) return _noop;
    state = state.copyWith(blockedUserIds: {...state.blockedUserIds, userId});
    return () => unblockUser(userId);
  }

  void unblockUser(String userId) {
    if (!state.blockedUserIds.contains(userId)) return;
    state = state.copyWith(
      blockedUserIds: {...state.blockedUserIds}..remove(userId),
    );
  }

  static void _noop() {}
}

/// [receivedInteractionsProvider] without anything hidden, reported or
/// blocked on this device.
final visibleReceivedInteractionsProvider =
    Provider<AsyncValue<List<InteractionRecord>>>((ref) {
      final filter = ref.watch(safetyFilterProvider);
      return _whereAsync(
        ref.watch(receivedInteractionsProvider),
        filter.allowsInteraction,
      );
    });

/// Every recent vote, answered and anonymous ones included, for the Inbox's
/// counts and its hide/report/block list. [receivedInteractionsProvider] only
/// returns the Play queue (votes still waiting for an answer), which Play and
/// the tab badge refresh often. Loaded only while the Inbox is open.
final inboxInteractionsProvider =
    FutureProvider.autoDispose<List<InteractionRecord>>((ref) async {
      final userId = await ref.watch(
        authControllerProvider.selectAsync((session) => session?.user.id),
      );
      if (userId == null) {
        throw const AppException('You need to sign in to view interactions.');
      }
      return ref
          .watch(interactionRepositoryProvider)
          .getReceivedInteractions(history: true);
    });

/// [inboxInteractionsProvider] without what the user hid, reported or blocked.
final visibleInboxInteractionsProvider =
    Provider.autoDispose<AsyncValue<List<InteractionRecord>>>((ref) {
      final filter = ref.watch(safetyFilterProvider);
      return _whereAsync(
        ref.watch(inboxInteractionsProvider),
        filter.allowsInteraction,
      );
    });

/// [matchesProvider] without anything hidden, reported or blocked on this
/// device.
final visibleMatchesProvider = Provider<AsyncValue<List<MatchRecord>>>((ref) {
  final filter = ref.watch(safetyFilterProvider);
  return _whereAsync(ref.watch(matchesProvider), filter.allowsMatch);
});

/// The Play queue: visible votes the user can still answer.
final pendingPlayInteractionsProvider =
    Provider<AsyncValue<List<InteractionRecord>>>((ref) {
      return _whereAsync(
        ref.watch(visibleReceivedInteractionsProvider),
        isActionablePlayInteraction,
      );
    });

/// Filters the list inside [source] while keeping its loading and error
/// flags, so a refetch keeps showing the previous (filtered) items instead of
/// a spinner. `whenData` would drop the previous items while reloading.
AsyncValue<List<T>> _whereAsync<T>(
  AsyncValue<List<T>> source,
  bool Function(T item) keep,
) {
  final items = source.valueOrNull;
  if (items == null) return source;
  final filtered = AsyncData<List<T>>(items.where(keep).toList());
  return source.map(
    data:
        (data) =>
            data.isLoading
                ? AsyncLoading<List<T>>().copyWithPrevious(filtered)
                : filtered,
    loading:
        (_) => AsyncLoading<List<T>>().copyWithPrevious(
          filtered,
          isRefresh: false,
        ),
    error:
        (error) => AsyncError<List<T>>(
          error.error,
          error.stackTrace,
        ).copyWithPrevious(filtered),
  );
}

final interactionControllerProvider =
    AsyncNotifierProvider<InteractionController, void>(
      InteractionController.new,
    );

final Set<String> _deferredFinalizeInFlight = <String>{};
final Set<String> _deferredFinalizeProcessed = <String>{};

// Reactions are created exclusively through the reveal-token -> finalize flow,
// which the backend gates with a 60s expiry window. We deliberately do NOT
// auto-send an interaction from a bare share code. Doing so produced a play card
// even after the reveal link had expired (and double-fired on the success path):
// when a token finalize failed, clearing the token re-triggered this provider and
// fell through to the non-expiring share-code send. Opening a profile/share link
// should let the user install/sign up, but must never create a reaction by itself.
final deferredInteractionFinalizerProvider = Provider<void>((ref) {
  final authStatus = ref.watch(authStatusProvider);
  final onboardingComplete =
      ref.watch(onboardingCompletionProvider).value ?? false;
  final token = ref.watch(deferredInteractionTokenProvider);

  if (authStatus != AuthStatus.authenticated || !onboardingComplete) {
    return;
  }

  if (token == null) {
    return;
  }

  if (_deferredFinalizeInFlight.contains(token) ||
      _deferredFinalizeProcessed.contains(token)) {
    return;
  }
  _deferredFinalizeInFlight.add(token);
  debugPrint('[DeferredInteraction] Auto-finalizing token: $token');
  Future.microtask(() async {
    try {
      await ref
          .read(interactionControllerProvider.notifier)
          .finalizeInteraction(token);
      _deferredFinalizeProcessed.add(token);
      ref.read(deferredInteractionTokenProvider.notifier).state = null;
    } catch (e) {
      debugPrint('[DeferredInteraction] Finalize failed: $e');
      ref
          .read(deferredInteractionErrorProvider.notifier)
          .state = _friendlyDeferredError(e);
      if (e is AppException &&
          e.statusCode != null &&
          e.statusCode! >= 400 &&
          e.statusCode! < 500) {
        // Terminal failure — mark processed so it is never retried, and clear
        // all deferred deep-link state so no other path acts on this link.
        _deferredFinalizeProcessed.add(token);
        ref.read(deferredInteractionTokenProvider.notifier).state = null;
        ref.read(deferredShareCodeProvider.notifier).state = null;
        ref.read(deferredInteractionTypeProvider.notifier).state = null;

        // "Already used" means the install referrer replayed a stale token
        // (e.g. same phone, data cleared, new account). No real user hits this
        // in a legitimate flow — show nothing.
        final msg = e.message;
        if (msg.contains('already been used') ||
            msg.contains('already been sent')) {
          return;
        }
      }
    } finally {
      _deferredFinalizeInFlight.remove(token);
    }
  });
});

String _friendlyDeferredError(Object error) {
  final message = error is AppException ? error.message : error.toString();
  if (message.contains('sent to yourself') || message.contains('own profile')) {
    return "You can't reveal or respond to your own link.";
  }
  if (message.contains('expired')) {
    return 'This reveal link has expired. Ask for a new one.';
  }
  if (message.contains('already been used')) {
    return 'This reveal link has already been used.';
  }
  if (message.contains('already been sent')) {
    return 'You already responded to this profile.';
  }
  return message.isEmpty
      ? 'Could not open this reveal link. Please try again.'
      : message;
}

class InteractionController extends AsyncNotifier<void> {
  InteractionRepository get _repository =>
      ref.read(interactionRepositoryProvider);

  @override
  Future<void> build() async {
    // Ensure the finalizer is initialized
    ref.read(deferredInteractionFinalizerProvider);
  }

  Future<InteractionResult> sendInteraction({
    required String shareCode,
    required InteractionType type,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.sendInteraction(
        shareCode: shareCode,
        type: type,
      );
      ref.invalidate(matchesProvider);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<InteractionResult> respondToInteraction({
    String? targetUserId,
    String? interactionId,
    required InteractionType type,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.respondToInteraction(
        targetUserId: targetUserId,
        interactionId: interactionId,
        type: type,
      );
      ref.invalidate(matchesProvider);
      ref.invalidate(receivedInteractionsProvider);
      ref.invalidate(pendingPlayInteractionsProvider);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<InteractionResult> finalizeInteraction(String token) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.finalizeInteraction(token);
      ref.invalidate(matchesProvider);
      ref.invalidate(receivedInteractionsProvider);
      ref.invalidate(pendingPlayInteractionsProvider);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
