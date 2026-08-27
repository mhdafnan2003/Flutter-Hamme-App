import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hamme_app/core/widgets/animated_spoiler.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'match_share_export_widget.dart';

class MatchThemeConfig {
  final List<Color> bgGradient;
  final Color solidBorder;
  final Color socialPillColor;
  final String emoji;
  final String choiceText;

  const MatchThemeConfig({
    required this.bgGradient,
    required this.solidBorder,
    required this.socialPillColor,
    required this.emoji,
    required this.choiceText,
  });

  static MatchThemeConfig fromType(InteractionType type) {
    switch (type) {
      case InteractionType.crush:
        return const MatchThemeConfig(
          bgGradient: [Color(0xFFCF59E7), Color(0xFFFF3C9E)],
          solidBorder: Color(0xFFFF3C9E),
          socialPillColor: Color(0xFFF589DE),
          emoji: '😍',
          choiceText: 'Crush',
        );
      case InteractionType.friend:
        return const MatchThemeConfig(
          bgGradient: [Color(0xFF00D1FF), Color(0xFF0066FF)],
          solidBorder: Color(0xFF0066FF),
          socialPillColor: Color(0xFF8992F5),
          emoji: '🤝',
          choiceText: 'Friend',
        );
      case InteractionType.frenemy:
        return const MatchThemeConfig(
          bgGradient: [Color(0xFFA5A5D7), Color(0xFF676798)],
          solidBorder: Color(0xFF676798),
          socialPillColor: Color(0xFF89A7F5),
          emoji: '😈',
          choiceText: 'Frenemy',
        );
    }
  }
}

/// Full-screen celebration shown immediately after a new match is created.
/// Existing matches use MatchReplyScreen instead, so this screen has no Reply
/// action.
class MatchSuccessOverlay extends StatefulWidget {
  const MatchSuccessOverlay({
    super.key,
    required this.result,
    required this.currentUserImageUrl,
    required this.onDismiss,
  });

  final InteractionResult result;
  final String? currentUserImageUrl;
  final VoidCallback onDismiss;

  @override
  State<MatchSuccessOverlay> createState() => _MatchSuccessOverlayState();
}

class _MatchSuccessOverlayState extends State<MatchSuccessOverlay> {
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _triggerMatchHaptics();
  }

  Future<void> _triggerMatchHaptics() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    HapticFeedback.heavyImpact();
  }

  Future<Uint8List> _renderShareImage({
    required String otherName,
    String? otherImageUrl,
  }) async {
    final boundaryKey = GlobalKey();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (_) => Positioned(
            left: -20000,
            top: 0,
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 1080,
                height: 1920,
                child: MatchShareExportWidget(
                  type: widget.result.interaction.type,
                  otherName: otherName,
                  otherImageUrl: otherImageUrl,
                  myImageUrl: widget.currentUserImageUrl,
                ),
              ),
            ),
          ),
    );

    Overlay.of(context, rootOverlay: true).insert(entry);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Boundary not available');

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Failed to convert to PNG');
      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  Future<void> _shareMatch() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final interaction = widget.result.interaction;
      final match = widget.result.match;
      final otherName =
          match?.matchedUser.name.trim().isNotEmpty == true
              ? match!.matchedUser.name.trim()
              : interaction.fromUserName?.trim().isNotEmpty == true
              ? interaction.fromUserName!.trim()
              : 'Someone';
      final otherImageUrl =
          match?.matchedUser.avatarUrl ?? interaction.fromUserProfileImageUrl;

      final bytes = await _renderShareImage(
        otherName: otherName,
        otherImageUrl: otherImageUrl,
      );
      final tempDir = await getTemporaryDirectory();
      final file =
          await File(
            '${tempDir.path}/hamme_match_${DateTime.now().millisecondsSinceEpoch}.png',
          ).create();
      await file.writeAsBytes(bytes);

      final subject = switch (interaction.type) {
        InteractionType.crush => "It's a crush match! 😍",
        InteractionType.friend => 'We matched as friends! 🤝',
        InteractionType.frenemy => 'Frenemy vibes only 😈',
      };
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: subject),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.result.interaction;
    final match = widget.result.match;
    final isAnonymous = match?.anonymous == true;
    final otherName =
        match?.matchedUser.name.trim().isNotEmpty == true
            ? match!.matchedUser.name.trim()
            : interaction.fromUserName?.trim().isNotEmpty == true
            ? interaction.fromUserName!.trim()
            : interaction.fromUserUsername?.trim().isNotEmpty == true
            ? interaction.fromUserUsername!.trim()
            : 'Someone';
    final otherImageUrl =
        isAnonymous
            ? null
            : match?.matchedUser.avatarUrl ??
                interaction.fromUserProfileImageUrl;
    final theme = MatchThemeConfig.fromType(interaction.type);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: 24,
                top: 20,
                child: AppCloseCircleButton(onPressed: widget.onDismiss),
              ),
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 58),
                            height: 225,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(48),
                              border: Border.all(
                                color: theme.solidBorder,
                                width: 8,
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                58,
                                16,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 8,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "It's a Match!",
                                    style: TextStyle(
                                      fontFamily: TFonts.nunito,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _MatchDescription(
                                    otherName: otherName,
                                    choiceText: theme.choiceText,
                                    anonymous: isAnonymous,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: MatchAvatarPair(
                              currentUserImageUrl: widget.currentUserImageUrl,
                              currentUserFallbackText: 'Y',
                              otherImageUrl: otherImageUrl,
                              otherFallbackText: otherName.characters.first,
                              ringColor: theme.solidBorder,
                              centerIcon: EmojiImage(
                                emoji: theme.emoji,
                                size: 36,
                              ),
                              plainOtherAvatar: isAnonymous,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 64),
                      if (!isAnonymous) ...[
                        _ActionButton(
                          onPressed: _isSharing ? null : _shareMatch,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF30415A),
                          child:
                              _isSharing
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF30415A),
                                    ),
                                  )
                                  : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.ios_share, size: 22),
                                      SizedBox(width: 8),
                                      Text('Share this match with friends'),
                                    ],
                                  ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _ActionButton(
                        onPressed: widget.onDismiss,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        child: const Text('Try Another Profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.8),
          disabledForegroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _MatchDescription extends StatelessWidget {
  const _MatchDescription({
    required this.otherName,
    required this.choiceText,
    required this.anonymous,
  });

  final String otherName;
  final String choiceText;
  final bool anonymous;

  static const _style = TextStyle(
    fontFamily: TFonts.nunito,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (anonymous)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnimatedSpoiler(
                width: 92,
                height: 19,
                particleColor: Colors.white,
              ),
              Text(' also chose $choiceText.', style: _style),
            ],
          )
        else
          Text(
            '$otherName also chose $choiceText.',
            maxLines: 1,
            style: _style,
            textAlign: TextAlign.center,
          ),
        const Text(
          'You both want the same thing.',
          textAlign: TextAlign.center,
          style: _style,
        ),
      ],
    );
  }
}

/// Brings the two matching profiles together with a short entrance animation.
class MatchAvatarPair extends StatefulWidget {
  const MatchAvatarPair({
    super.key,
    required this.currentUserImageUrl,
    required this.currentUserFallbackText,
    required this.otherImageUrl,
    required this.otherFallbackText,
    required this.ringColor,
    required this.centerIcon,
    this.plainOtherAvatar = false,
  });

  final String? currentUserImageUrl;
  final String currentUserFallbackText;
  final String? otherImageUrl;
  final String otherFallbackText;
  final Color ringColor;
  final Widget centerIcon;
  final bool plainOtherAvatar;

  @override
  State<MatchAvatarPair> createState() => _MatchAvatarPairState();
}

class _MatchAvatarPairState extends State<MatchAvatarPair>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        final arrival = Curves.easeOutBack.transform(_entranceController.value);
        final centerScale = Curves.easeOutBack.transform(
          Interval(0.56, 1).transform(_entranceController.value),
        );

        return SizedBox(
          width: 225,
          height: 116,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                child: Transform.translate(
                  offset: Offset(-190 * (1 - arrival), 0),
                  child: Transform.scale(
                    scale: 0.86 + (0.14 * arrival),
                    child: MatchAvatar(
                      imageUrl: widget.currentUserImageUrl,
                      fallbackText: widget.currentUserFallbackText,
                      ringColor: widget.ringColor,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Transform.translate(
                  offset: Offset(190 * (1 - arrival), 0),
                  child: Transform.scale(
                    scale: 0.86 + (0.14 * arrival),
                    child: MatchAvatar(
                      imageUrl: widget.otherImageUrl,
                      fallbackText: widget.otherFallbackText,
                      ringColor: widget.ringColor,
                      plainCircle: widget.plainOtherAvatar,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: centerScale,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: widget.centerIcon,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MatchAvatar extends StatelessWidget {
  const MatchAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    required this.ringColor,
    this.plainCircle = false,
  });

  final String? imageUrl;
  final String fallbackText;
  final Color ringColor;
  final bool plainCircle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child:
            plainCircle
                ? const SizedBox.expand()
                : ClipOval(
                  child:
                      imageUrl != null && imageUrl!.isNotEmpty
                          ? Image.network(imageUrl!, fit: BoxFit.cover)
                          : Container(
                            color: const Color(0xFFF2F2F7),
                            alignment: Alignment.center,
                            child: Text(
                              fallbackText.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                ),
      ),
    );
  }
}
