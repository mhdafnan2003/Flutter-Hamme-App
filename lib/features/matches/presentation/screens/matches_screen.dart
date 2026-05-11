import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/matches/presentation/widgets/skeleton_match_card.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: TColors.hammeSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.back,
                        color: TColors.black,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(TImages.hammeHomeLogo, height: 34),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: matches.when(
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyMatchesView();
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        for (final match in items) ...[
                          _MatchCard(match: match),
                          const SizedBox(height: 18),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
                loading: () => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: const [
                      SizedBox(height: 60),
                      SkeletonMatchCard(),
                      SizedBox(height: 24),
                      SkeletonMatchCard(),
                      SizedBox(height: 24),
                      SkeletonMatchCard(),
                    ],
                  ),
                ),
                error: (error, _) => Center(
                  child: Text(
                    'Could not load matches.',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: TColors.darkGrey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMatchesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          const SizedBox(height: 122),
          const Text(
            'No matches yet 🥺',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE92AEF),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'A match happens when someone\npicks the same option as you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: TColors.black,
            ),
          ),
          const SizedBox(height: 42),
          const Text(
            'Go play to find yours',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: TColors.darkGrey,
            ),
          ),
          const SizedBox(height: 34),
          const SkeletonMatchCard(),
          const SizedBox(height: 24),
          const SkeletonMatchCard(),
          const SizedBox(height: 24),
          const SkeletonMatchCard(),
          const SizedBox(height: 28),
          const Text(
            '🧨 Matches are vanished after 24hrs',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: TColors.darkGrey,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final user = match.matchedUser;
    final avatarUrl = user.profileImageUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TColors.hammeSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: TColors.white,
            backgroundImage:
                avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
            child:
                avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(
                      CupertinoIcons.person_solid,
                      size: 20,
                      color: TColors.darkGrey,
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: TColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  match.type.label,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: TColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.heart_fill,
            color: Color(0xFFE92AEF),
            size: 18,
          ),
        ],
      ),
    );
  }
}
