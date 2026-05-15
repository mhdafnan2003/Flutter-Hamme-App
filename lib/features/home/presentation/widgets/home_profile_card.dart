import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class HomeProfileCard extends ConsumerWidget {
  const HomeProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider).value ?? const OnboardingDraft();
    final profileName =
        (draft.name != null && draft.name!.trim().isNotEmpty)
            ? draft.name!.trim()
            : TTexts.homeProfileName;
    final profileImageUrl = draft.profileImageUrl;
    final hasProfileImage =
      profileImageUrl != null && profileImageUrl.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: TColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: const BoxDecoration(
                  color: TColors.hammePrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      top: 16,
                      right: 16,
                      child: Icon(
                        CupertinoIcons.pencil,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          profileName,
                          style: const TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: TColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  TTexts.homePrompt,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: TColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -50,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TColors.white, width: 4),
                  color: TColors.hammeSurface,
                ),
                child: hasProfileImage
                    ? ClipOval(
                      child: Image.network(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                      ),
                    )
                    : const Icon(
                  CupertinoIcons.person_solid,
                  size: 50,
                  color: TColors.grey,
                ),
              ),
        if (draft.socialPlatform != null && draft.socialPlatform!.isNotEmpty)
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Image.asset(
                  draft.socialPlatform == TTexts.socialInstagram
                      ? TImages.instagramIcon
                      : TImages.snapchatIcon,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: draft.socialPlatform == TTexts.socialSnapchat
                            ? TColors.snapchatYellow
                            : TColors.hammePrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        draft.socialPlatform == TTexts.socialInstagram
                            ? CupertinoIcons.camera_fill
                            : CupertinoIcons.chat_bubble_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    );
  }
}
