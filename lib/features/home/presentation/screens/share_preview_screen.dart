import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class SharePreviewScreen extends ConsumerWidget {
  const SharePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final profileImagePath = draft.profileImagePath;
    final hasProfileImage =
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        File(profileImagePath).existsSync();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9E6EFE), Color(0xFF7737FD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back Button
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
                  onPressed: () => context.pop(),
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 60),

                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // What do you think of me pill
                      Padding(
                        padding: const EdgeInsets.only(top: 90),
                        child: Container(
                          height: 46,
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            
                          ),
                          child: const Text(
                            'What do you think of me?',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),

                      // Avatar
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 5),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: Colors.black.withValues(alpha: 0.25),
                          //     blurRadius: 4,
                          //     offset: const Offset(0, 4),
                          //   ),
                          // ],
                          color: TColors.hammeSurface,
                        ),
                        child: hasProfileImage
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
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  _buildOptionButton(
                    text: 'Friend',
                    emoji: '🤝',
                    colors: const [Color(0xFF00CCFE), Color(0xFF005EFB)],
                  ),
                  const SizedBox(height: 12),
                  _buildOptionButton(
                    text: 'Crush',
                    emoji: '😍',
                    colors: const [Color(0xFFCE58E6), Color(0xFFFE3B9D)],
                  ),
                  const SizedBox(height: 12),
                  _buildOptionButton(
                    text: 'Frenemy',
                    emoji: '😈',
                    colors: const [Color(0xFFBBADED), Color(0xFF50528D)],
                  ),

                  const Spacer(),

                  // Send me anonymously Tooltip
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'send me anonymously',
                          style: TextStyle(
                            fontFamily: 'SchibstedGrotesk', // Fallback to Nunito if needed, we'll use a bold default
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -6,
                        child: CustomPaint(
                          size: const Size(16, 8),
                          painter: TrianglePainter(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Link Sticker
                  Container(
                    width: 160,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CustomPaint(
                      painter: DashedBorderPainter(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFF00CCFE), width: 2),
                            ),
                            child: const Icon(
                              CupertinoIcons.link,
                              color: Color(0xFF00CCFE),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PLACE LINK',
                                style: TextStyle(
                                  fontFamily: TFonts.nunito,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Colors.black,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'STICKER HERE',
                                style: TextStyle(
                                  fontFamily: TFonts.nunito,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Colors.black,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Arrows
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.3,
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 40),
                      const SizedBox(width: 16),
                      Transform.rotate(
                        angle: 0.3,
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 40),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Footer Logo
                  Column(
                    children: [
                      Image.asset(
                        TImages.hammeLogo,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'play games & meet people',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({required String text, required String emoji, required List<Color> colors}) {
    return Container(
      width: 260,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    const double dashWidth = 8;
    const double dashSpace = 6;
    double distance = 0;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0; // Reset for next metric if any
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
