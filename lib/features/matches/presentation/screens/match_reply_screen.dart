import 'package:flutter/material.dart';
import 'package:hamme_app/core/widgets/animated_spoiler.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_success_overlay.dart'
    show MatchAvatarPair, MatchThemeConfig;
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Details shown when a user opens an existing match from the Matches list.
///
/// This is intentionally separate from MatchSuccessOverlay: the latter is the
/// one-time celebration shown immediately after a new match is created.
class MatchReplyScreen extends StatelessWidget {
  const MatchReplyScreen({
    super.key,
    required this.match,
    required this.currentUserImageUrl,
  });

  final MatchRecord match;
  final String? currentUserImageUrl;

  bool get _isAnonymous => match.anonymous;

  bool get _isSnapchat {
    final user = match.matchedUser;
    return _handle.toLowerCase().contains('snap') ||
        user.email.toLowerCase().contains('snap') ||
        user.name.toLowerCase().contains('snap') ||
        user.id.toLowerCase().contains('snap');
  }

  String get _handle {
    final user = match.matchedUser;
    final value =
        user.instagramId.trim().isNotEmpty ? user.instagramId : user.shareCode;
    return value.replaceAll('@', '').trim();
  }

  Future<void> _openSocial() async {
    if (_isAnonymous || _handle.isEmpty) return;

    final appUrl =
        _isSnapchat
            ? Uri.parse('snapchat://add/$_handle')
            : Uri.parse('instagram://user?username=$_handle');
    final webUrl =
        _isSnapchat
            ? Uri.parse('https://www.snapchat.com/add/$_handle')
            : Uri.parse('https://www.instagram.com/$_handle/');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      debugPrint('Could not open social profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = match.matchedUser;
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Someone';
    final theme = MatchThemeConfig.fromType(match.type);

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
                child: AppCloseCircleButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
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
                                  _ReplyDescription(
                                    name: name,
                                    choiceText: theme.choiceText,
                                    anonymous: _isAnonymous,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: MatchAvatarPair(
                              currentUserImageUrl: currentUserImageUrl,
                              currentUserFallbackText: 'Y',
                              otherImageUrl:
                                  _isAnonymous ? null : user.avatarUrl,
                              otherFallbackText: name.characters.first,
                              ringColor: theme.solidBorder,
                              centerIcon: EmojiImage(
                                emoji: theme.emoji,
                                size: 36,
                              ),
                              plainOtherAvatar: _isAnonymous,
                            ),
                          ),
                        ],
                      ),
                      if (!_isAnonymous) ...[
                        const SizedBox(height: 48),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 62,
                            child: ElevatedButton.icon(
                              onPressed: _openSocial,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                elevation: 0,
                              ),
                              icon: Image.asset(
                                _isSnapchat
                                    ? 'assets/icons/snap-fill.png'
                                    : 'assets/icons/insta-outline.png',
                                width: 24,
                                height: 24,
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

class _ReplyDescription extends StatelessWidget {
  const _ReplyDescription({
    required this.name,
    required this.choiceText,
    required this.anonymous,
  });

  final String name;
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
            '$name also chose $choiceText.',
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
