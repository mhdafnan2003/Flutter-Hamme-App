import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class PlayEmptyState extends StatelessWidget {
  const PlayEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final frontW = w - 8;
        final backW = frontW * 226 / 345;
        final midW = frontW * 290 / 345;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 215,
              width: w,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 0,
                    child: Container(
                      width: backW,
                      height: 203,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xDBF0F0F0)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    child: Container(
                      width: midW,
                      height: 203,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xDBF0F0F0)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    child: Container(
                      key: const Key('play-empty-front-card'),
                      width: frontW,
                      height: 186,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBE5F6),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No one here yet',
                                style: TextStyle(
                                  fontFamily: TFonts.nunito,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  color: Color(0xFFFF22F0),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Image.asset(
                                'assets/icons/emoji_pleading.png',
                                width: 32,
                                height: 32,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 39),
            const Text(
              TTexts.playEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ],
        );
      },
    );
  }
}
