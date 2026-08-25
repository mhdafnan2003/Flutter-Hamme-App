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

  static const double _tilt = -4 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        (profileImageUrl != null && profileImageUrl!.isNotEmpty) ||
        selectedImageBytes != null ||
        previewBytes != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PromptChip(
          iconPath: TImages.iconClockCircle,
          iconSize: 20,
          height: 38,
          label: TTexts.onboardingRecentPhoto,
        ),
        const SizedBox(height: 4),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: _tilt,
              child: const _PromptChip(
                iconPath: TImages.iconUserRectangle,
                iconSize: 17,
                height: 35,
                label: TTexts.onboardingShowFace,
              ),
            ),
            Transform.translate(
              offset: const Offset(8, -8),
              child: Transform.rotate(
                angle: _tilt,
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
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -8),
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
    required this.iconPath,
    required this.iconSize,
    required this.height,
    required this.label,
  });

  final String iconPath;
  final double iconSize;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 10, right: 14),
      decoration: BoxDecoration(
        color: TColors.hammeChip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(iconPath, width: iconSize, height: iconSize),
          const SizedBox(width: 6),
          Text(
            label,
            softWrap: false,
            style: const TextStyle(
              fontFamily: TFonts.schibstedGrotesk,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1,
              letterSpacing: -0.9,
              color: Colors.white,
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
      child: SvgPicture.asset(
        TImages.iconPlus,
        width: 24,
        height: 24,
        clipBehavior: Clip.none,
      ),
    );
  }
}
