import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
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
                    const _SkeletonMatchCard(),
                    const SizedBox(height: 24),
                    const _SkeletonMatchCard(),
                    const SizedBox(height: 24),
                    const _SkeletonMatchCard(),
                    const SizedBox(height: 24),
                    const _SkeletonMatchCard(),
                    const SizedBox(height: 24),
                    const _SkeletonMatchCard(),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonMatchCard extends StatelessWidget {
  const _SkeletonMatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: TColors.grey.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
