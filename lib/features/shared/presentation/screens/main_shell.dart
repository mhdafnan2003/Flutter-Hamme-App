import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import '../widgets/hamme_bottom_nav_bar.dart';

/// Persistent shell that hosts the main tabs (Share / Play / Inbox).
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
    final pendingPlay = ref.watch(pendingPlayInteractionsProvider);
    final playCount = pendingPlay.maybeWhen(
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
