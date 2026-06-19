import 'package:flutter/material.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class PlayEmptyState extends StatelessWidget {
  const PlayEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final backW = w * 0.72;
        final midW = w * 0.86;
        final frontW = w;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 260,
              width: w,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 0,
                    child: Container(
                      width: backW,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    child: Container(
                      width: midW,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 22,
                    child: Container(
                      width: frontW,
                      height: 210,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E8FF),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCDBDFF).withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No one here yet',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              color: Color(0xFFFF00FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const EmojiImage(emoji: '🥺', size: 26),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              TTexts.playEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.3,
                color: TColors.black,
              ),
            ),
          ],
        );
      },
    );
  }
}
