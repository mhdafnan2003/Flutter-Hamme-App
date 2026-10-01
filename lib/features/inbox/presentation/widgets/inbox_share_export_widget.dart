import 'package:flutter/material.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/features/inbox/presentation/widgets/inbox_reaction_card.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

/// Renders the Figma Inbox reaction card on a platform-compatible 9:16 canvas.
/// It is captured off-screen before sharing to Instagram / Snapchat Stories.
class InboxShareExportWidget extends StatelessWidget {
  final InboxVariation variation;
  final int count;
  final String? profileImageUrl;

  /// Platform: 'instagram' | 'snapchat' (cosmetic only – drives badge color).
  final bool isInstagram;

  const InboxShareExportWidget({
    super.key,
    required this.variation,
    required this.count,
    this.profileImageUrl,
    this.isInstagram = true,
  });

  static const double _designW = 393;
  static const double _designH = 852;
  static const double _canvasW = 1080;
  static const double _canvasH = 1920;

  List<Color> get _backgroundColors => switch (variation.typeKey) {
    'friend' => const [Color(0xFF00CCFE), Color(0xFF005EFB)],
    'frenemy' => const [Color(0xFFB8ADED), Color(0xFF50528D)],
    _ => const [Color(0xFFCF59E7), Color(0xFFFF3C9E)],
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : _canvasW;
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : _canvasH;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _backgroundColors,
            ),
          ),
          // Fit the 393×852 Figma composition uniformly into the 9:16 export
          // canvas. This keeps circles and card corners undistorted.
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _designW,
                height: _designH,
                child: Stack(
                  children: [
                    Positioned(
                      top: 220,
                      left: 0,
                      right: 0,
                      height: 283,
                      child: InboxReactionCard(
                        variation: variation,
                        count: count,
                        imageUrl: profileImageUrl,
                        showEmptyState: false,
                      ),
                    ),
                    Positioned(
                      top: 631,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Hamme',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: TFonts.nunito,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 675,
                      left: 0,
                      right: 0,
                      child: Text(
                        'play games  &  meet people',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: TFonts.schibstedGrotesk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.84,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
