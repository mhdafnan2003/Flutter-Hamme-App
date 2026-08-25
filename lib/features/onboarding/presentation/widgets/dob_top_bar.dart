import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class DobTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final double progress;
  final Widget? trailing;

  const DobTopBar({
    super.key,
    this.onBack,
    this.progress = 0.35,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(
                    TImages.iconArrowLeft,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            SizedBox(
              width: 170,
              child: Stack(
                children: [
                  Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: TColors.hammeTrack,
                      borderRadius: BorderRadius.circular(4.5),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: TColors.hammeProgressFill,
                        borderRadius: BorderRadius.circular(4.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing!),
          ],
        ),
      ),
    );
  }
}
