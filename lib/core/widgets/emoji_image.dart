import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

/// Renders an emoji as a PNG asset image for platform-consistent appearance.
///
/// Maps the emoji string (😍, 🤝, 😈) to its corresponding asset file.
/// Falls back to a [Text] widget if no matching asset is found.
class EmojiImage extends StatelessWidget {
  const EmojiImage({
    required this.emoji,
    this.size = 24,
    super.key,
  });

  final String emoji;
  final double size;

  static String? assetFor(String emoji) {
    switch (emoji) {
      case '😍':
        return TImages.emojiCrush;
      case '🤝':
        return TImages.emojiFriend;
      case '😈':
        return TImages.emojiFrenemy;
      case '🎂':
        return TImages.emojiBirthday;
      case '📸':
        return TImages.emojiCamera;
      case '🗣️':
        return TImages.emojiSpeaking;
      case '⏳':
        return TImages.emojiHourglass;
      case '👀':
        return TImages.emojiEyes;
      case '🥺':
        return TImages.emojiPleading;
      case '🚨':
        return TImages.emojiAlert;
      case '🙈':
        return TImages.emojiMonkey;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(emoji);
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    // Fallback to text emoji
    return Text(emoji, style: TextStyle(fontSize: size * 0.85));
  }
}
