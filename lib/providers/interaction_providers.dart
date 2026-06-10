import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../features/interactions/data/datasources/interaction_remote_data_source.dart';
import '../features/interactions/data/repositories/interaction_repository_impl.dart';
import '../features/interactions/domain/repositories/interaction_repository.dart';
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

final matchesProvider = FutureProvider<List<MatchRecord>>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    throw const AppException('You need to sign in to view matches.');
  }
  return ref.watch(interactionRepositoryProvider).getMatches();
});

final receivedInteractionsProvider = FutureProvider<List<InteractionRecord>>((ref) async {
  debugPrint('[Inbox] fetch start');
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) {
    debugPrint('[Inbox] skipped fetch: no auth token');
    throw const AppException('You need to sign in to view interactions.');
  }

  final items = await ref.watch(interactionRepositoryProvider).getReceivedInteractions();
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

final pendingPlayInteractionsProvider = FutureProvider<List<InteractionRecord>>((ref) async {
  final items = await ref.watch(receivedInteractionsProvider.future);
  return items
      .where(
        (item) =>
            item.fromUser != null &&
            item.fromUser!.isNotEmpty &&
            !item.respondedByCurrentUser,
      )
      .toList();
});

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
  final onboardingComplete = ref.watch(onboardingCompletionProvider).value ?? false;
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
      await ref.read(interactionControllerProvider.notifier).finalizeInteraction(token);
      _deferredFinalizeProcessed.add(token);
      ref.read(deferredInteractionTokenProvider.notifier).state = null;
    } catch (e) {
      debugPrint('[DeferredInteraction] Finalize failed: $e');
      ref.read(deferredInteractionErrorProvider.notifier).state =
          _friendlyDeferredError(e);
      if (e is AppException &&
          e.statusCode != null &&
          e.statusCode! >= 400 &&
          e.statusCode! < 500) {
        // Terminal failure (expired / already used / self). Mark it processed so
        // it is never retried, and clear all deferred deep-link state so no other
        // path acts on this expired link.
        _deferredFinalizeProcessed.add(token);
        ref.read(deferredInteractionTokenProvider.notifier).state = null;
        ref.read(deferredShareCodeProvider.notifier).state = null;
        ref.read(deferredInteractionTypeProvider.notifier).state = null;
      }
    } finally {
      _deferredFinalizeInFlight.remove(token);
    }
  });
});

String _friendlyDeferredError(Object error) {
  final message = error is AppException ? error.message : error.toString();
  if (message.contains('sent to yourself') ||
      message.contains('own profile')) {
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

  Future<InteractionResult> respondToUser({
    required String targetUserId,
    required InteractionType type,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.respondToUser(
        targetUserId: targetUserId,
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
