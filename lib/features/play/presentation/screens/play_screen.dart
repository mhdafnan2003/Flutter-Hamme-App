import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import '../../../shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import '../../../shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/play_empty_state.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(receivedInteractionsProvider);
      ref.invalidate(pendingPlayInteractionsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(receivedInteractionsProvider);
      ref.invalidate(pendingPlayInteractionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingPlayInteractionsProvider);
    final controller = ref.watch(interactionControllerProvider);

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const HammeTopBar(),

            Expanded(
              child: pending.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const _CompletedQueueView();
                  }

                  final current = items.first;
                  return _PlayQueue(
                    item: current,
                    remainingCount: items.length,
                    isSubmitting: controller.isLoading,
                    onSelect: (type) async {
                      final targetUserId = current.fromUser;
                      if (targetUserId == null || targetUserId.isEmpty) return;
                      try {
                        final result = await ref
                            .read(interactionControllerProvider.notifier)
                            .respondToUser(
                              targetUserId: targetUserId,
                              type: type,
                            );

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.matched
                                  ? 'It is a match!'
                                  : 'Response saved.',
                            ),
                            backgroundColor: result.matched
                                ? TColors.hammeInboxPinkEnd
                                : TColors.hammePrimaryDark,
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not save response: $error'),
                            backgroundColor: TColors.error,
                          ),
                        );
                      }
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Could not load voters.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HammeBottomNavBar(
        currentIndex: 1,
        playBadgeCount: pending.maybeWhen(
          data: (items) => items.length,
          orElse: () => null,
        ),
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 2) {
            context.go('/inbox');
          }
        },
      ),
    );
  }
}

class _PlayQueue extends StatelessWidget {
  const _PlayQueue({
    required this.item,
    required this.remainingCount,
    required this.isSubmitting,
    required this.onSelect,
  });

  final InteractionRecord item;
  final int remainingCount;
  final bool isSubmitting;
  final ValueChanged<InteractionType> onSelect;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = item.fromUserProfileImageUrl;
    final name = item.fromUserName?.trim().isNotEmpty == true
        ? item.fromUserName!.trim()
        : item.fromUserUsername?.trim().isNotEmpty == true
            ? item.fromUserUsername!.trim()
            : 'Someone';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$remainingCount reacted to you',
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: TColors.hammePrimaryDark,
              ),
            ),
          ),
          const SizedBox(height: 34),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 54),
                decoration: BoxDecoration(
                  color: TColors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 92,
                      decoration: const BoxDecoration(
                        color: TColors.hammePrimary,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          color: TColors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        'What do you think of me?',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          color: TColors.black,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 54,
                backgroundColor: const Color(0xFFAEE5F2),
                backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: TColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 48),
          _ResponseButton(
            label: 'Friend',
            emoji: '🤝',
            colors: const [Color(0xFF01CAFD), Color(0xFF0162FA)],
            disabled: isSubmitting,
            onTap: () => onSelect(InteractionType.friend),
          ),
          const SizedBox(height: 14),
          _ResponseButton(
            label: 'Crush',
            emoji: '😍',
            colors: const [Color(0xFFCE58E6), Color(0xFFFE3B9D)],
            disabled: isSubmitting,
            onTap: () => onSelect(InteractionType.crush),
          ),
          const SizedBox(height: 14),
          _ResponseButton(
            label: 'Frenemy',
            emoji: '😈',
            colors: const [Color(0xFFB3A8E8), Color(0xFF535590)],
            disabled: isSubmitting,
            onTap: () => onSelect(InteractionType.frenemy),
          ),
        ],
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.emoji,
    required this.colors,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final List<Color> colors;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextButton(
          onPressed: disabled ? null : onTap,
          child: Text(
            '$emoji $label',
            style: const TextStyle(
              color: TColors.white,
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedQueueView extends StatelessWidget {
  const _CompletedQueueView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlayEmptyState(),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.push('/matches'),
              child: const Text(
                'See matches',
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w900,
                  color: TColors.hammePrimaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
