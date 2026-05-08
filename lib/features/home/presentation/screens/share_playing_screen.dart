import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/home/presentation/widgets/playing_friends_row.dart';
import 'package:hamme_app/features/home/presentation/widgets/share_option_button.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class SharePlayingScreen extends ConsumerWidget {
  const SharePlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider).value ?? const OnboardingDraft();
    final profileImagePath = draft.profileImagePath;
    final hasProfileImage =
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        (kIsWeb || File(profileImagePath).existsSync());

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFA36FFF), Color(0xFF7636FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 10,
                child: IconButton(
                  icon: const Icon(
                    CupertinoIcons.back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => context.go('/share'),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 393),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 104),
                        Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 92),
                              child: Container(
                                height: 36,
                                width: double.infinity,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'What do you think of me?',
                                  style: TextStyle(
                                    fontFamily: TFonts.nunito,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 5,
                                ),
                                color: TColors.hammeSurface,
                              ),
                              child: hasProfileImage ? ClipOval(
                                child: kIsWeb
                                    ? Image.network(
                                      profileImagePath!,
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                    )
                                    : Image.file(
                                      File(profileImagePath!),
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                    ),
                              ) : const Icon(
                                CupertinoIcons.person_solid,
                                size: 50,
                                color: TColors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '🙊 send anonymously',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const ShareOptionButton(
                          text: 'Friend',
                          emoji: '\u{1F91D}',
                          colors: [Color(0xFF14D5F5), Color(0xFF0067FF)],
                        ),
                        const SizedBox(height: 12),
                        const ShareOptionButton(
                          text: 'Crush',
                          emoji: '\u{1F60D}',
                          colors: [Color(0xFFD74CDB), Color(0xFFFF3190)],
                        ),
                        const SizedBox(height: 12),
                        const ShareOptionButton(
                          text: 'Frenemy',
                          emoji: '\u{1F608}',
                          colors: [Color(0xFFB6A8EA), Color(0xFF595A96)],
                        ),
                        const SizedBox(height: 42),
                        const PlayingFriendsRow(),
                        const SizedBox(height: 10),
                        const Text(
                          '👆 6 friends playing now 👆',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 98),
                        Image.asset(
                          TImages.hammeLogo,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'play games & meet people',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Terms    Privacy',
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
