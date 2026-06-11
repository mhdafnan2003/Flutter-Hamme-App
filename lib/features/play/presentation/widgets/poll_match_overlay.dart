import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'match_success_overlay.dart' show MatchThemeConfig, MatchAvatar;

/// Shown to the original poller (Person B who voted via share link) when
/// Person A responds in the play screen and a match is created.
class PollMatchOverlay extends StatefulWidget {
  const PollMatchOverlay({
    super.key,
    required this.match,
    required this.currentUserImageUrl,
    required this.onDismiss,
  });

  final MatchRecord match;
  final String? currentUserImageUrl;
  final VoidCallback onDismiss;

  @override
  State<PollMatchOverlay> createState() => _PollMatchOverlayState();
}

class _PollMatchOverlayState extends State<PollMatchOverlay> {
  String get _otherInstagram => widget.match.matchedUser.instagramId;
  // AppUser doesn't carry snapchat — instagram only for this path
  bool get _hasInstagram => _otherInstagram.isNotEmpty;

  Future<void> _openSocial() async {
    final handle = _otherInstagram.replaceAll('@', '');
    if (handle.isEmpty) return;

    final appUrl = Uri.parse('instagram://user?username=$handle');
    final webUrl = Uri.parse('https://www.instagram.com/$handle/');
    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open Instagram: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MatchThemeConfig.fromType(widget.match.type);
    final otherName = widget.match.matchedUser.name.trim().isNotEmpty
        ? widget.match.matchedUser.name.trim()
        : 'Someone';
    final otherImageUrl = widget.match.matchedUser.avatarUrl;

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
              // Close button
              Positioned(
                right: 20,
                top: 20,
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
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
                        // Match card with overlapping avatars
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
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
                                      'You and $otherName both chose ${theme.choiceText}.',
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
                                    Positioned(
                                      left: 45,
                                      child: MatchAvatar(
                                        imageUrl: widget.currentUserImageUrl,
                                        fallbackText: 'Y',
                                        ringColor: theme.solidBorder,
                                      ),
                                    ),
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

                        // Reply button (Instagram only — snapchat not in AppUser)
                        if (_hasInstagram)
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
                                'assets/icons/insta-outline.png',
                                width: 24,
                                height: 24,
                                color: Colors.white,
                                errorBuilder: (_, __, ___) => const Icon(
                                  CupertinoIcons.camera_fill,
                                  size: 22,
                                  color: Colors.white,
                                ),
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
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton(
                              onPressed: widget.onDismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Continue',
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
