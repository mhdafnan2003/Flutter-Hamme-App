import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import '../../../shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import '../../../shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/inbox_reaction_card.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<InboxVariation> _variations = const [
    InboxVariation(
      gradientColors: [TColors.hammeInboxPinkStart, TColors.hammeInboxPinkEnd],
      borderColor: TColors.hammeInboxPinkBorder,
      emoji: '😍',
      typeKey: 'crush',
    ),
    InboxVariation(
      gradientColors: [TColors.hammeInboxBlueStart, TColors.hammeInboxBlueEnd],
      borderColor: TColors.hammeInboxBlueBorder,
      emoji: '🤝',
      typeKey: 'friend',
    ),
    InboxVariation(
      gradientColors: [
        TColors.hammeInboxPurpleStart,
        TColors.hammeInboxPurpleEnd,
      ],
      borderColor: TColors.hammeInboxPurpleBorder,
      emoji: '😈',
      typeKey: 'frenemy',
    ),
  ];

  int _countByType(Map<String, int> counts, String key) {
    if (key == 'frenemy') {
      return (counts['frenemy'] ?? 0) + (counts['ameny'] ?? 0);
    }
    return counts[key] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(receivedInteractionsProvider);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingPlay = ref.watch(pendingPlayInteractionsProvider);
    final playCount = pendingPlay.maybeWhen(
      data: (items) => items.length,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const HammeTopBar(),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      final interactions = ref.watch(receivedInteractionsProvider);
                      return interactions.when(
                        data: (items) {
                          final counts = <String, int>{};
                          for (final item in items) {
                            final key = item.type.name;
                            counts[key] = (counts[key] ?? 0) + 1;
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Current counts:\nCrush: ${_countByType(counts, 'crush')}\nFriend: ${_countByType(counts, 'friend')}\nFrenemy: ${_countByType(counts, 'frenemy')}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: TColors.darkGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 360,
                                child: PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemCount: _variations.length,
                                  itemBuilder: (context, index) {
                                    final variation = _variations[index];
                                    final count = _countByType(counts, variation.typeKey);
                                    return InboxReactionCard(
                                      variation: variation,
                                      count: count,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => SizedBox(
                          height: 360,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemCount: _variations.length,
                            itemBuilder: (context, index) {
                              final variation = _variations[index];
                              return InboxReactionCard(
                                variation: variation,
                                count: 0,
                              );
                            },
                          ),
                        ),
                        error: (_, __) => SizedBox(
                          height: 360,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemCount: _variations.length,
                            itemBuilder: (context, index) {
                              final variation = _variations[index];
                              return InboxReactionCard(
                                variation: variation,
                                count: 0,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _variations.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 16 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index
                                  ? TColors.black
                                  : TColors.grey,
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HammeBottomNavBar(
        currentIndex: 2,
        playBadgeCount: playCount,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/play');
          }
        },
      ),
    );
  }
}
