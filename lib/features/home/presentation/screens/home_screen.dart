import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../core/widgets/gradient_button.dart';
import '../../../shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import '../../../shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/home_profile_card.dart';
import '../widgets/home_step_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(onboardingDraftProvider).username?.trim();
    final normalizedUsername =
        (username != null && username.isNotEmpty)
            ? username.replaceAll('@', '')
            : null;
    final shareLink =
        normalizedUsername == null
            ? TTexts.homeShareLink
            : 'HAMME/APP/$normalizedUsername';

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            HammeTopBar(onLeftTap: () => context.push('/matches')),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    const HomeProfileCard(),

                    const SizedBox(height: 24),

                    HomeStepCard(
                      title: TTexts.homeStepOneTitle,
                      subtitle: shareLink,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Container(
                        width: 150,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: TColors.hammePrimaryDark,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              CupertinoIcons.link,
                              color: TColors.hammePrimaryDark,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              TTexts.homeCopyLink,
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: TColors.hammePrimaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    HomeStepCard(
                      title: TTexts.homeStepTwoTitle,
                      child: SizedBox(
                        width: 250,
                        child: GradientButton(
                          label: TTexts.homeShareAction,
                          onTap: () {
                            context.push('/share');
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: 250,
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(onboardingCompletionProvider.notifier)
                              .reset();
                          if (!context.mounted) return;
                          context.go('/onboarding/dob');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: TColors.hammePrimaryDark,
                            width: 2,
                          ),
                          foregroundColor: TColors.hammePrimaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Go to onboarding',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HammeBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            context.go('/play');
          } else if (index == 2) {
            context.go('/inbox');
          }
        },
      ),
    );
  }
}
