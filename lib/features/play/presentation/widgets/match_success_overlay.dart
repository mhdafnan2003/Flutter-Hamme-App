import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchThemeConfig {
  final List<Color> bgGradient;
  final Color solidBorder;
  final Color closeIconColor;
  final String emoji;
  final String choiceText;

  const MatchThemeConfig({
    required this.bgGradient,
    required this.solidBorder,
    required this.closeIconColor,
    required this.emoji,
    required this.choiceText,
  });

  static MatchThemeConfig fromType(InteractionType type) {
    switch (type) {
      case InteractionType.crush:
        return const MatchThemeConfig(
          bgGradient: [Color(0xFFCF59E7), Color(0xFFFF3C9E)],
          solidBorder: Color(0xFFFF3C9E),
          closeIconColor: Color(0xFFC75AF6),
          emoji: '😍',
          choiceText: 'Crush',
        );
      case InteractionType.friend:
        return const MatchThemeConfig(
          bgGradient: [Color(0xFF00D1FF), Color(0xFF0066FF)],
          solidBorder: Color(0xFF0066FF),
          closeIconColor: Color(0xFF0099FF),
          emoji: '🤝',
          choiceText: 'Friend',
        );
      case InteractionType.frenemy:
        return const MatchThemeConfig(
          bgGradient: [Color(0xFFA5A5D7), Color(0xFF676798)],
          solidBorder: Color(0xFF676798),
          closeIconColor: Color(0xFF8B8CB5),
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

  Future<void> _openSocial() async {
    final interaction = widget.result.interaction;
    final match = widget.result.match;
    final otherInstagram = match?.matchedUser.instagramId ?? interaction.fromUserInstagramId ?? '';
    final otherSnap = interaction.fromUserSnapchatId ?? '';

    final handle = (_isInstagramSelected ? otherInstagram : otherSnap).replaceAll('@', '');
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
        final webUrl = !_isInstagramSelected
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
    
    final otherName = match?.matchedUser.name.trim()
        ?? interaction.fromUserName?.trim()
        ?? interaction.fromUserUsername?.trim()
        ?? 'Someone';
    final otherImageUrl = match?.matchedUser.avatarUrl
        ?? interaction.fromUserProfileImageUrl;

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
                right: 20,
                top: 20,
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 18,
                      color: theme.closeIconColor,
                    ),
                  ),
                ),
              ),
              
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                              margin: const EdgeInsets.only(top: 60),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: theme.solidBorder,
                                  width: 6,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(44),
                                  border: Border.all(color: Colors.white, width: 8),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "It's a Match!",
                                      style: TextStyle(
                                        fontFamily: TFonts.nunito,
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${otherName.isEmpty ? "Someone" : otherName} also chose ${theme.choiceText}.\nYou both want the same thing.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: TFonts.nunito,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Avatars
                            Positioned(
                              top: 0,
                              child: SizedBox(
                                width: 300,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Current User
                                    Positioned(
                                      left: 45,
                                      child: MatchAvatar(
                                        imageUrl: widget.currentUserImageUrl,
                                        fallbackText: 'Y',
                                        ringColor: theme.solidBorder,
                                      ),
                                    ),
                                    // Matched User
                                    Positioned(
                                      right: 45,
                                      child: MatchAvatar(
                                        imageUrl: otherImageUrl,
                                        fallbackText: otherName.isNotEmpty
                                            ? otherName.characters.first
                                            : 'A',
                                        ringColor: theme.solidBorder,
                                      ),
                                    ),
                                    // Emoji Center
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          theme.emoji,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Social Platform Switcher
                        Container(
                          width: 100,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Stack(
                            children: [
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                alignment: _isInstagramSelected
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.solidBorder,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isInstagramSelected = true),
                                      child: Center(
                                        child: Image.asset(
                                          'assets/icons/insta-outline.png',
                                          width: 24,
                                          height: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isInstagramSelected = false),
                                      child: Center(
                                        child: Image.asset(
                                          'assets/icons/snap-fill.png',
                                          width: 24,
                                          height: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Reply Button
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton.icon(
                            onPressed: _openSocial,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            icon: Image.asset(
                              _isInstagramSelected
                                  ? 'assets/icons/insta-outline.png'
                                  : 'assets/icons/snap-fill.png',
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Reply',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
          child: imageUrl != null && imageUrl!.isNotEmpty
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
