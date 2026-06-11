import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/play_limit_status.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import 'billing_providers.dart';

final playLimitStatusProvider = FutureProvider<PlayLimitStatus>((ref) async {
  final session = await ref.watch(authControllerProvider.future);
  if (session == null) return PlayLimitStatus.unrestricted;

  // Pro users bypass the limit locally — no need to hit the network
  final isPro = ref.watch(isProProvider);
  if (isPro) return PlayLimitStatus.unrestricted;

  try {
    final api = ref.read(apiServiceProvider);
    final response = await api.get(
          '/interactions/limit-status',
          authenticated: true,
        ) as Map<String, dynamic>;

    final statusJson = response['cardLimitStatus'] as Map<String, dynamic>?;
    if (statusJson == null) return PlayLimitStatus.unrestricted;

    return PlayLimitStatus.fromJson(statusJson);
  } catch (_) {
    // If we can't fetch limit status, don't block the user
    return PlayLimitStatus.unrestricted;
  }
});
