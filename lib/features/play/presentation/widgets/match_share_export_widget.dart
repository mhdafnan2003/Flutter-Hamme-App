import 'package:flutter/material.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

import 'match_success_overlay.dart' show MatchAvatarPair;

/// Fits the 393 × 852 Figma match story uniformly into the 1080 × 1920 capture.
/// The background fills the extra canvas width without stretching the artwork.
class MatchShareExportWidget extends StatelessWidget {
  const MatchShareExportWidget({
    super.key,
    required this.type,
    required this.otherName,
    this.otherImageUrl,
    this.myImageUrl,
    this.anonymous = false,
  });

  /// Resolve share content once, before rendering, so fallback interaction data
  /// cannot reveal the voter behind an anonymous match.
  factory MatchShareExportWidget.fromResult({
    required InteractionResult result,
    String? myImageUrl,
  }) {
    final match = result.match;
    final interaction = result.interaction;
    final anonymous = match?.anonymous == true;
    final name = match?.matchedUser.name.trim();
    final fallbackName = interaction.fromUserName?.trim();
    return MatchShareExportWidget(
      type: interaction.type,
      anonymous: anonymous,
      otherName:
          anonymous
              ? 'Anonymous'
              : name?.isNotEmpty == true
              ? name!
              : fallbackName?.isNotEmpty == true
              ? fallbackName!
              : 'Someone',
      otherImageUrl:
          anonymous
              ? null
              : match?.matchedUser.avatarUrl ??
                  interaction.fromUserProfileImageUrl,
      myImageUrl: myImageUrl,
    );
  }

  final InteractionType type;
  final String otherName;
  final String? otherImageUrl;
  final String? myImageUrl;
  final bool anonymous;

  static const double _designW = 393;
  static const double _designH = 852;

  _MatchExportTheme get _theme => switch (type) {
    InteractionType.friend => const _MatchExportTheme(
      colors: [Color(0xFF00CCFE), Color(0xFF005EFB)],
      border: Color(0xFF005FFC),
      avatarRing: Color(0xFF005FFC),
      label: 'Friend',
      emojiAsset: 'assets/icons/emoji_friend.png',
    ),
    InteractionType.frenemy => const _MatchExportTheme(
      colors: [Color(0xFFB8ADED), Color(0xFF50528D)],
      border: Color(0xFF535B97),
      avatarRing: Color(0xFF535B97),
      label: 'Frenemy',
      emojiAsset: 'assets/icons/emoji_frenemy.png',
      emojiSize: 30,
    ),
    InteractionType.crush => const _MatchExportTheme(
      colors: [Color(0xFFCF59E7), Color(0xFFFF3C9E)],
      border: Color(0xFFFF3C9E),
      avatarRing: Color(0xFFF43F5E),
      label: 'Crush',
      emojiAsset: 'assets/icons/emoji_crush.png',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final displayName =
        anonymous
            ? 'Anonymous'
            : otherName.trim().isEmpty
            ? 'Someone'
            : otherName.trim();

    return MediaQuery(
      data: (MediaQuery.maybeOf(context) ?? const MediaQueryData()).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 1080.0;
            final height =
                constraints.maxHeight.isFinite ? constraints.maxHeight : 1920.0;
            return Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.colors,
                ),
              ),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _designW,
                    height: _designH,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 16,
                          top: 278,
                          width: 361,
                          height: 225,
                          child: DecoratedBox(
                            key: const Key('match-export-outer-card'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(48),
                              border: Border.all(color: theme.border, width: 8),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          top: 283,
                          width: 345,
                          height: 212,
                          child: DecoratedBox(
                            key: const Key('match-export-inner-card'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: Colors.white, width: 8),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 84,
                          top: 220,
                          child: MatchAvatarPair(
                            key: const Key('match-export-avatars'),
                            animate: false,
                            plainOtherAvatar: anonymous,
                            currentUserImageUrl: myImageUrl,
                            currentUserFallbackText: 'Y',
                            otherImageUrl: anonymous ? null : otherImageUrl,
                            otherFallbackText: displayName.characters.first,
                            ringColor: theme.avatarRing,
                            centerIcon: Transform.translate(
                              offset: Offset(
                                0,
                                type == InteractionType.frenemy ? 2 : 0,
                              ),
                              child: Image.asset(
                                theme.emojiAsset,
                                width: theme.emojiSize,
                                height: theme.emojiSize,
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 16,
                          right: 16,
                          top: 352,
                          height: 49,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'It’s a Match!',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                height: 49 / 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 80,
                          top: 413,
                          width: 233,
                          height: 44,
                          child: FittedBox(
                            key: const Key('match-export-description'),
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$displayName also chose ${theme.label}.',
                                  style: _descriptionStyle,
                                ),
                                const Text(
                                  'You both want the same thing.',
                                  style: _descriptionStyle,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 631,
                          height: 38,
                          child: Stack(
                            key: const Key('match-export-wordmark'),
                            alignment: Alignment.center,
                            children: [
                              Text(
                                'Hamme',
                                style: TextStyle(
                                  fontFamily: TFonts.nunito,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 38 / 28,
                                  foreground:
                                      Paint()
                                        ..style = PaintingStyle.stroke
                                        ..strokeWidth = 8
                                        ..color = Colors.black,
                                ),
                              ),
                              const Text(
                                'Hamme',
                                style: TextStyle(
                                  fontFamily: TFonts.nunito,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 38 / 28,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 675,
                          height: 17,
                          child: Text(
                            'play games  &  meet people',
                            key: Key('match-export-footer'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TFonts.schibstedGrotesk,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 17 / 14,
                              letterSpacing: -0.84,
                              color: Colors.white,
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
        ),
      ),
    );
  }

  static const _descriptionStyle = TextStyle(
    fontFamily: TFonts.nunito,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 22 / 16,
    color: Colors.white,
  );
}

class _MatchExportTheme {
  const _MatchExportTheme({
    required this.colors,
    required this.border,
    required this.avatarRing,
    required this.label,
    required this.emojiAsset,
    this.emojiSize = 36,
  });
  final List<Color> colors;
  final Color border;
  final Color avatarRing;
  final String label;
  final String emojiAsset;
  final double emojiSize;
}
