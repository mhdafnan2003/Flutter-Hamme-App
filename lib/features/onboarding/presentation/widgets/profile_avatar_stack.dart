import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class ProfileAvatarStack extends StatelessWidget {
  const ProfileAvatarStack({
    super.key,
    required this.onPickImage,
    this.previewBytes,
    this.profileImageUrl,
    this.selectedImageBytes,
  });

  final VoidCallback onPickImage;
  final Uint8List? previewBytes;
  final String? profileImageUrl;
  final Uint8List? selectedImageBytes;

  static const double _rotate = -4 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        (profileImageUrl != null && profileImageUrl!.isNotEmpty) ||
        selectedImageBytes != null ||
        previewBytes != null;

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 0,
            left: 29,
            child: _PromptChip(
              width: 192,
              height: 38,
              iconPath: TImages.iconClockCircle,
              iconSize: 20,
              label: TTexts.onboardingRecentPhoto,
            ),
          ),
          Positioned(
            top: 34,
            left: 14,
            child: Transform.rotate(
              angle: _rotate,
              child: const _PromptChip(
                width: 223,
                height: 35,
                iconPath: TImages.iconUserRectangle,
                iconSize: 17,
                label: TTexts.onboardingShowFace,
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 108,
            child: Transform.rotate(
              angle: _rotate,
              child: Transform.scale(
                scaleY: -1,
                child: SvgPicture.asset(
                  TImages.iconSpeechTail,
                  width: 34,
                  height: 20,
                ),
              ),
            ),
          ),
          Positioned(
            top: 92,
            left: 46,
            child: GestureDetector(
              onTap: onPickImage,
              child: SizedBox(
                width: 158,
                height: 158,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 158,
                      height: 158,
                      decoration: const BoxDecoration(
                        color: TColors.hammeAvatarFill,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          hasImage
                              ? _ProfileImage(
                                profileImageUrl: profileImageUrl,
                                selectedImageBytes: selectedImageBytes,
                                previewBytes: previewBytes,
                              )
                              : Center(
                                child: SvgPicture.asset(
                                  TImages.iconUserFilled,
                                  width: 60,
                                  height: 60,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                    ),
                    const Positioned(
                      right: 7,
                      bottom: 7,
                      child: _PlusBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({
    required this.profileImageUrl,
    required this.selectedImageBytes,
    required this.previewBytes,
  });

  final String? profileImageUrl;
  final Uint8List? selectedImageBytes;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return Image.network(profileImageUrl!, fit: BoxFit.cover);
    }
    if (selectedImageBytes != null) {
      return Image.memory(selectedImageBytes!, fit: BoxFit.cover);
    }
    return Image.memory(previewBytes!, fit: BoxFit.cover);
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.width,
    required this.height,
    required this.iconPath,
    required this.iconSize,
    required this.label,
  });

  final double width;
  final double height;
  final String iconPath;
  final double iconSize;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: TColors.hammeChip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SvgPicture.asset(iconPath, width: iconSize, height: iconSize),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: TFonts.schibstedGrotesk,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1,
                letterSpacing: -0.9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlusBadge extends StatelessWidget {
  const _PlusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: TColors.hammePlusBadge,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(TImages.iconPlus, width: 24, height: 24),
    );
  }
}
