import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/play_limit_status.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import 'billing_providers.dart';

final playLimitStatusProvider =
    AsyncNotifierProvider<PlayLimitStatusNotifier, PlayLimitStatus>(
      PlayLimitStatusNotifier.new,
    );

class PlayLimitStatusNotifier extends AsyncNotifier<PlayLimitStatus> {
  @override
  Future<PlayLimitStatus> build() async {
    // Only a change of account changes the limit. Watching the whole session
    // re-fetched this on every session write (app resume, profile edits).
    final userId = await ref.watch(
      authControllerProvider.selectAsync((session) => session?.user.id),
    );
    if (userId == null) return PlayLimitStatus.unrestricted;

    // Pro users bypass the limit locally — no need to hit the network
    final isPro = ref.watch(isProProvider);
    if (isPro) return PlayLimitStatus.unrestricted;

    try {
      final api = ref.read(apiServiceProvider);
      final response =
          await api.get('/interactions/limit-status', authenticated: true)
              as Map<String, dynamic>;

      final statusJson = response['cardLimitStatus'] as Map<String, dynamic>?;
      if (statusJson == null) return PlayLimitStatus.unrestricted;

      return PlayLimitStatus.fromJson(statusJson);
    } catch (_) {
      // If we can't fetch limit status, don't block the user. Keep them a free
      // user though (not `unrestricted`, which claims Pro), so a vote the
      // server rejects with 429 is still handled as a card-limit error.
      return const PlayLimitStatus(limited: false, isPro: false);
    }
  }

  /// Shows [status], which the server returned with a vote, instead of
  /// fetching it again.
  void apply(PlayLimitStatus status) => state = AsyncData(status);
}
