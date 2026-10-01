import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/push_data_refresh_provider.dart';
import 'package:hamme_app/providers/settings_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import '../widgets/hamme_bottom_nav_bar.dart';

/// Persistent shell with Share and Play tabs and a retained Inbox route.
///
/// The bottom navigation bar stays mounted while only the body swaps between
/// branches via [StatefulNavigationShell], so switching tabs no longer rebuilds
/// the whole screen and each tab keeps its own state.
class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // Re-tapping the active tab pops it back to its initial location.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // New votes and matches arrive by push while the app is open; this keeps
    // the Play data fresh without polling.
    ref.watch(pushDataRefreshProvider);
    // A notification setting changed while offline still reaches the server.
    ref.watch(notificationSettingsRetryProvider);

    final pendingPlay = ref.watch(pendingPlayInteractionsProvider);
    final playCount = pendingPlay.maybeWhen(
      // Keep the badge while a refresh is in flight instead of blinking it off.
      skipLoadingOnReload: true,
      data: (items) => items.length,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: TColors.white,
      body: navigationShell,
      bottomNavigationBar: HammeBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        playBadgeCount: playCount,
        onTap: _onTap,
      ),
    );
  }
}
