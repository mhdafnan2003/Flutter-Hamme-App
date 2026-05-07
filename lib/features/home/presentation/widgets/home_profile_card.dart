import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class HomeProfileCard extends ConsumerWidget {
  const HomeProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final profileName =
        (draft.name != null && draft.name!.trim().isNotEmpty)
            ? draft.name!.trim()
            : TTexts.homeProfileName;
    final profileImagePath = draft.profileImagePath;
    final hasProfileImage =
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        File(profileImagePath).existsSync();

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
                child:
                    hasProfileImage
                        ? ClipOval(
                          child: Image.file(
                            File(profileImagePath),
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
              Positioned(
                bottom: 4,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: TColors.instagramGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
                        color: Colors.white,
                        size: 14,
                      ),
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
