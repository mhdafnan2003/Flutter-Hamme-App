import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

/// Renders a 1080 × 1920 (9:16) story image that matches the reference
/// design exactly. Used as the off-screen RepaintBoundary source before
/// sharing to Instagram / Snapchat Stories.
class InboxShareExportWidget extends StatelessWidget {
  final InboxVariation variation;
  final int count;
  final String? profileImageUrl;
  /// Platform: 'instagram' | 'snapchat'  (cosmetic only – drives badge color)
  final bool isInstagram;

  const InboxShareExportWidget({
    super.key,
    required this.variation,
    required this.count,
    this.profileImageUrl,
    this.isInstagram = true,
  });

  // ── canvas constants (all in logical pixels at pixelRatio 1.0) ──────────
  static const double _canvasW = 1080;
  static const double _canvasH = 1920;

  // Card geometry – mirrors the in-app card but scaled for 1080 px width
  static const double _cardW        = 820;
  static const double _cardH        = 520;
  static const double _borderW      = 16;
  static const double _cornerR      = 104;
  static const double _avatarSize   = 220;
  static const double _avatarHalf   = _avatarSize / 2;
  static const double _emojiBadge   = 92;
  static const double _emojiOffset  = _avatarSize - 52;

  @override
  Widget build(BuildContext context) {
    final hasImage = profileImageUrl != null && profileImageUrl!.isNotEmpty;
    final subtitle = count == 1
        ? '1 person has ${variation.typeKey} on you'
        : '$count people have ${variation.typeKey} on you';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _canvasW,
        height: _canvasH,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(variation.gradientColors.first, 0.12),
              variation.gradientColors.last,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Vertically centred content column ───────────────────────
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Reaction Card ──────────────────────────────────────
                  SizedBox(
                    width: _cardW,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Card body – pushed down by half-avatar overhang
                        Container(
                          margin: const EdgeInsets.only(top: _avatarHalf),
                          width: _cardW,
                          height: _cardH,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: variation.borderColor,
                              width: _borderW,
                            ),
                            borderRadius: BorderRadius.circular(_cornerR),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: variation.gradientColors,
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(_cornerR - 12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // top padding to clear the avatar overhang
                                const SizedBox(height: 80),
                                // Reaction count
                                Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    fontFamily: TFonts.nunito,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 112,
                                    height: 1,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Subtitle
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: TFonts.nunito,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 36,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Tagline pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(60),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    variation.tagline,
                                    style: const TextStyle(
                                      fontFamily: TFonts.nunito,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 30,
                                      color: Colors.white,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // ── Floating Avatar ──────────────────────────────
                        Positioned(
                          top: 0,
                          child: Container(
                            width: _avatarSize,
                            height: _avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: variation.borderColor,
                                  width: 6,
                                ),
                              ),
                              child: ClipOval(
                                child: hasImage
                                    ? Image.network(
                                        profileImageUrl!,
                                        fit: BoxFit.cover,
                                        width: _avatarSize,
                                        height: _avatarSize,
                                        errorBuilder: (_, __, ___) =>
                                            _avatarFallback(),
                                      )
                                    : _avatarFallback(),
                              ),
                            ),
                          ),
                        ),

                        // ── Emoji Badge ──────────────────────────────────
                        Positioned(
                          top: _emojiOffset,
                          child: Container(
                            width: _emojiBadge,
                            height: _emojiBadge,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: EmojiImage(
                                emoji: variation.emoji,
                                size: 52,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Bottom Branding ─────────────────────────────────────────
            Positioned(
              bottom: 140,
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'play games & meet people',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w700,
                      fontSize: 34,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: Colors.white24,
        child: const Icon(
          CupertinoIcons.person_solid,
          size: 100,
          color: Colors.white70,
        ),
      );

  /// Slightly lighten a color for the top gradient stop.
  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
