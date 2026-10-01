import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../core/widgets/gradient_button.dart';
import '../../../shared/presentation/widgets/hamme_top_bar.dart';
import '../widgets/home_profile_card.dart';
import '../widgets/home_step_card.dart';
import 'package:hamme_app/utils/popups/app_snack_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final shareCode = session?.user.shareCode;
    final shareLink = AppConstants.buildUserShareLink(shareCode);

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            HammeTopBar(
              onLeftTap: () => context.push('/matches'),
              onRightTap: () => context.push('/profile'),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The reference canvas leaves generous blank space around
                  // the cards. Shorter phones use that space to keep Share
                  // visible above the bottom navigation.
                  final room = ((constraints.maxHeight - 535) / 113).clamp(
                    0.0,
                    1.0,
                  );
                  final profileGap = 53 + 27 * room;
                  final firstCardGap = 4 + 36 * room;
                  final secondCardGap = 8 + 10 * room;
                  final bottomGap = 40 * room;

                  return SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SizedBox(height: profileGap),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: HomeProfileCard(),
                        ),
                        SizedBox(height: firstCardGap),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: HomeStepCard(
                            title: TTexts.homeStepOneTitle,
                            subtitle: shareLink,
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            subtitleSpacing: 12,
                            childSpacing: 12,
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: shareLink),
                                );
                                AppSnackBar.show(
                                  context,
                                  'Link copied to clipboard!',
                                  type: AppSnackBarType.success,
                                  duration: const Duration(seconds: 2),
                                );
                              },
                              child: Container(
                                width: 150,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(
                                    color: TColors.hammePrimaryDark,
                                    width: 3,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/icons/copy.png',
                                      width: 16,
                                      height: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          TTexts.homeCopyLink,
                                          style: const TextStyle(
                                            fontFamily: TFonts.nunito,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            color: Color(0xFF884EFF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: secondCardGap),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: HomeStepCard(
                            title: TTexts.homeStepTwoTitle,
                            padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                            childSpacing: 14,
                            child: SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                label: TTexts.homeShareAction,
                                fontSize: 20,
                                // Always open the share intro so the user can
                                // pick Snapchat or Instagram each time.
                                onTap: () => context.push('/share'),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: bottomGap),

                        // SizedBox(
                        //   width: 250,
                        //   child: OutlinedButton(
                        //     onPressed: () async {
                        //       await ref
                        //           .read(onboardingCompletionProvider.notifier)
                        //           .reset();
                        //       if (!context.mounted) return;
                        //       context.go('/onboarding/dob');
                        //     },
                        //     style: OutlinedButton.styleFrom(
                        //       side: const BorderSide(
                        //         color: TColors.hammePrimaryDark,
                        //         width: 2,
                        //       ),
                        //       foregroundColor: TColors.hammePrimaryDark,
                        //       padding: const EdgeInsets.symmetric(vertical: 14),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(28),
                        //       ),
                        //     ),
                        //     child: const Text(
                        //       'Go to onboarding',
                        //       style: TextStyle(
                        //         fontFamily: TFonts.nunito,
                        //         fontWeight: FontWeight.w700,
                        //         fontSize: 16,
                        //       ),
                        //     ),
                        //   ),
                        // ),

                        // const SizedBox(height: 12),

                        // SizedBox(
                        //   width: 250,
                        //   child: OutlinedButton(
                        //     onPressed: () async {
                        //       await ref.read(authControllerProvider.notifier).logout();
                        //       if (!context.mounted) return;
                        //       context.go('/splash');
                        //     },
                        //     style: OutlinedButton.styleFrom(
                        //       side: const BorderSide(color: Colors.red, width: 2),
                        //       foregroundColor: Colors.red,
                        //       padding: const EdgeInsets.symmetric(vertical: 14),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(28),
                        //       ),
                        //     ),
                        //     child: const Text(
                        //       'Logout (Reset Tokens)',
                        //       style: TextStyle(
                        //         fontFamily: TFonts.nunito,
                        //         fontWeight: FontWeight.w700,
                        //         fontSize: 16,
                        //       ),
                        //     ),
                        //   ),
                        // ),

                        // const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
