import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class InboxReactionCard extends StatelessWidget {
  const InboxReactionCard({
    required this.variation,
    required this.count,
    this.imageUrl,
    super.key,
  });

  final InboxVariation variation;
  final int count;
  final String? imageUrl;

  String? get _emojiAsset {
    return switch (variation.typeKey) {
      'crush' => 'assets/icons/emoji_crush.png',
      'friend' => 'assets/icons/emoji_friend.png',
      'frenemy' => 'assets/icons/emoji_frenemy.png',
      _ => null,
    };
  }

  String get _message {
    if (count == 0) {
      return 'Numbers fill up the moment someone\n'
          'taps on your story link. Go share \u{1F446}';
    }
    if (count == 1) {
      return '1 person has ${variation.typeKey} on you';
    }
    return '$count people have ${variation.typeKey} on you';
  }

  @override
  Widget build(BuildContext context) {
    const avatarSize = 116.0;
    const outerCardTop = 58.0;
    const outerCardHeight = 225.0;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 361),
          child: SizedBox(
            width: double.infinity,
            height: outerCardTop + outerCardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: outerCardTop,
                  left: 0,
                  right: 0,
                  height: outerCardHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: variation.borderColor,
                        width: 8,
                      ),
                      borderRadius: BorderRadius.circular(48),
                    ),
                  ),
                ),
                Positioned(
                  top: 63,
                  left: 8,
                  right: 8,
                  height: 212,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: variation.gradientColors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: Colors.white, width: 8),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: variation.borderColor,
                        width: 3,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child:
                            imageUrl != null && imageUrl!.isNotEmpty
                                ? Image.network(
                                  imageUrl!,
                                  width: avatarSize,
                                  height: avatarSize,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => const Icon(
                                        CupertinoIcons.person_solid,
                                        size: 52,
                                        color: Colors.grey,
                                      ),
                                )
                                : const Icon(
                                  CupertinoIcons.person_solid,
                                  size: 52,
                                  color: Colors.grey,
                                ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 90,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child:
                        _emojiAsset != null
                            ? Image.asset(
                              _emojiAsset!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                            )
                            : EmojiImage(emoji: variation.emoji, size: 36),
                  ),
                ),
                Positioned(
                  top: 138,
                  left: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 36,
                          height: 1.35,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x40000000),
                              blurRadius: 4,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _message,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.35,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            variation.tagline,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
