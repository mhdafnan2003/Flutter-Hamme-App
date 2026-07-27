import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isInstagramSelected = true;

  @override
  void initState() {
    super.initState();
    _triggerMatchHaptics();
  }

  Future<void> _triggerMatchHaptics() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.heavyImpact();
  }

  Future<void> _openSocial() async {
    final interaction = widget.result.interaction;
    final match = widget.result.match;
    final otherInstagram =
        match?.matchedUser.instagramId ?? interaction.fromUserInstagramId ?? '';
    final otherSnap = interaction.fromUserSnapchatId ?? '';

    final handle = (_isInstagramSelected ? otherInstagram : otherSnap)
        .replaceAll('@', '');
    if (handle.isEmpty) return;

    final Uri url;
    if (!_isInstagramSelected) {
      url = Uri.parse('snapchat://add/$handle');
    } else {
      url = Uri.parse('instagram://user?username=$handle');
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final webUrl =
            !_isInstagramSelected
                ? Uri.parse('https://www.snapchat.com/add/$handle')
                : Uri.parse('https://www.instagram.com/$handle/');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.result.interaction;
    final match = widget.result.match;

    final otherName =
        match?.matchedUser.name.trim() ??
        interaction.fromUserName?.trim() ??
        interaction.fromUserUsername?.trim() ??
        'Someone';
    final otherImageUrl =
        match?.matchedUser.avatarUrl ?? interaction.fromUserProfileImageUrl;

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
              // Close Button
              Positioned(
                right: 24,
                top: 20,
                child: AppCloseCircleButton(onPressed: widget.onDismiss),
              ),

              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Match Card
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            // Match Card (Double Border)
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
                                  color: Colors.transparent,
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
                                      otherName:
                                          otherName.isEmpty
                                              ? 'Someone'
                                              : otherName,
                                      choiceText: theme.choiceText,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Avatars
                            Positioned(
                              top: 0,
                              child: MatchAvatarPair(
                                currentUserImageUrl: widget.currentUserImageUrl,
                                currentUserFallbackText: 'Y',
                                otherImageUrl: otherImageUrl,
                                otherFallbackText:
                                    otherName.isNotEmpty
                                        ? otherName.characters.first
                                        : 'A',
                                ringColor: theme.solidBorder,
                                centerIcon: EmojiImage(
                                  emoji: theme.emoji,
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),

                        // Social Platform Switcher
                        Container(
                          width: 84,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Stack(
                            children: [
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                alignment:
                                    _isInstagramSelected
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.socialPillColor,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 9,
                                top: 9,
                                child: IgnorePointer(
                                  child: Image.asset(
                                    'assets/icons/insta-outline.png',
                                    width: 20,
                                    height: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 9,
                                top: 9.5,
                                child: IgnorePointer(
                                  child: Image.asset(
                                    'assets/icons/snap-fill.png',
                                    width: 20,
                                    height: 19,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            () => setState(
                                              () => _isInstagramSelected = true,
                                            ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            () => setState(
                                              () =>
                                                  _isInstagramSelected = false,
                                            ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Reply Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 62,
                            child: ElevatedButton.icon(
                              onPressed: _openSocial,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                elevation: 0,
                              ),
                              icon: Image.asset(
                                _isInstagramSelected
                                    ? 'assets/icons/insta-outline.png'
                                    : 'assets/icons/snap-fill.png',
                                width: 24,
                                height: _isInstagramSelected ? 24 : 22.8,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Reply',
                                style: TextStyle(
                                  fontFamily: TFonts.nunito,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _MatchDescription extends StatelessWidget {
  const _MatchDescription({required this.otherName, required this.choiceText});

  final String otherName;
  final String choiceText;

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
        SizedBox(
          width: double.infinity,
          height: 22.4,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$otherName also chose $choiceText.',
              maxLines: 1,
              style: _style,
            ),
          ),
        ),
        const Text(
          'You both want the same thing.',
          maxLines: 1,
          textAlign: TextAlign.center,
          style: _style,
        ),
      ],
    );
  }
}

/// Brings the two matching profiles together, then keeps a subtle glossy
/// highlight moving across them while the match screen is visible.
class MatchAvatarPair extends StatefulWidget {
  const MatchAvatarPair({
    super.key,
    required this.currentUserImageUrl,
    required this.currentUserFallbackText,
    required this.otherImageUrl,
    required this.otherFallbackText,
    required this.ringColor,
    required this.centerIcon,
  });

  final String? currentUserImageUrl;
  final String currentUserFallbackText;
  final String? otherImageUrl;
  final String otherFallbackText;
  final Color ringColor;
  final Widget centerIcon;

  @override
  State<MatchAvatarPair> createState() => _MatchAvatarPairState();
}

class _MatchAvatarPairState extends State<MatchAvatarPair>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glazeController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _glazeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glazeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _glazeController]),
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
                    child: _GlossyMatchAvatar(
                      glazeProgress: _glazeController.value,
                      avatar: MatchAvatar(
                        imageUrl: widget.currentUserImageUrl,
                        fallbackText: widget.currentUserFallbackText,
                        ringColor: widget.ringColor,
                      ),
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
                    child: _GlossyMatchAvatar(
                      glazeProgress: (_glazeController.value + 0.5) % 1,
                      avatar: MatchAvatar(
                        imageUrl: widget.otherImageUrl,
                        fallbackText: widget.otherFallbackText,
                        ringColor: widget.ringColor,
                      ),
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

class _GlossyMatchAvatar extends StatelessWidget {
  const _GlossyMatchAvatar({required this.avatar, required this.glazeProgress});

  final Widget avatar;
  final double glazeProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        children: [
          avatar,
          ClipOval(
            child: Transform.translate(
              offset: Offset(-150 + (300 * glazeProgress), 0),
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: 32,
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x99FFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchAvatar extends StatelessWidget {
  const MatchAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    required this.ringColor,
  });

  final String? imageUrl;
  final String fallbackText;
  final Color ringColor;

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
        child: ClipOval(
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
