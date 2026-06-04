import 'package:flutter/cupertino.dart';
import 'package:hamme_app/utils/constants/colors.dart';

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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onBack,
                child: const Icon(
                  CupertinoIcons.back,
                  size: 24,
                  color: TColors.darkGrey,
                ),
              ),
            ),
          SizedBox(
            width: 140,
            child: Stack(
              children: [
                // Background track
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: TColors.hammeTrack,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Filled portion
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: TColors.hammePrimary,
                      borderRadius: BorderRadius.circular(4),
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
    );
  }
}
