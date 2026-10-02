import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class PlayEmptyState extends StatelessWidget {
  const PlayEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 353),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final frontW = w - 8;
          final scale = frontW / 345;
          final backW = frontW * 226 / 345;
          final midW = frontW * 290 / 345;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 214 * scale,
                width: w,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 0,
                      child: Container(
                        width: backW,
                        key: const Key('play-empty-back-card'),
                        height: 203.378 * scale,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            // Figma flips these rectangles vertically: the
                            // visible top is gray, fading down to white.
                            colors: [Color(0xDBF0F0F0), Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(24 * scale),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 11.622 * scale,
                      child: Container(
                        width: midW,
                        key: const Key('play-empty-middle-card'),
                        height: 203.378 * scale,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xDBF0F0F0), Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(24 * scale),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 28 * scale,
                      child: Container(
                        key: const Key('play-empty-front-card'),
                        width: frontW,
                        height: 186 * scale,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBE5F6),
                          borderRadius: BorderRadius.circular(18 * scale),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      height: 38 / 28,
                                      color: Color(0xFFFF22F0),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Image.asset(
                                    'assets/icons/play_empty_pleading.png',
                                    width: 32,
                                    height: 32,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                TTexts.playEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 22 / 16,
                  color: Colors.black,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
