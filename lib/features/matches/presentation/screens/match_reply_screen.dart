import 'package:flutter/material.dart';
import 'package:hamme_app/core/widgets/animated_spoiler.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_success_overlay.dart'
    show MatchAvatarPair, MatchThemeConfig;
import 'package:hamme_app/features/safety/domain/models/safety_target.dart';
import 'package:hamme_app/features/safety/presentation/widgets/safety_actions.dart';
import 'package:hamme_app/features/safety/presentation/widgets/safety_menu_button.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/popups/app_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Details shown when a user opens an existing match from the Matches list.
///
/// This is intentionally separate from MatchSuccessOverlay: the latter is the
/// one-time celebration shown immediately after a new match is created.
class MatchReplyScreen extends StatefulWidget {
  const MatchReplyScreen({
    super.key,
    required this.match,
    required this.currentUserImageUrl,
    this.onDismiss,
    this.continueWhenUnavailable = false,
    this.showSafetyActions = true,
  });

  final MatchRecord match;
  final String? currentUserImageUrl;
  final VoidCallback? onDismiss;
  final bool continueWhenUnavailable;
  final bool showSafetyActions;

  @override
  State<MatchReplyScreen> createState() => _MatchReplyScreenState();
}

class _MatchReplyScreenState extends State<MatchReplyScreen> {
  bool? _selectedSnapchat;
  MatchRecord get match => widget.match;
  String? get currentUserImageUrl => widget.currentUserImageUrl;

  bool get _isAnonymous => match.anonymous;

  bool _socialAvailable(bool snapchat) =>
      !_isAnonymous &&
      (snapchat ? match.matchedUser.snapchatId : match.matchedUser.instagramId)
          .replaceAll('@', '')
          .trim()
          .isNotEmpty;

  // Prefer the matched user's Instagram; fall back to Snapchat when that is
  // the only handle they added.
  bool get _isSnapchat {
    final selected = _selectedSnapchat;
    if (selected != null && _socialAvailable(selected)) return selected;
    return !_socialAvailable(false) && _socialAvailable(true);
  }

  String get _handle {
    final user = match.matchedUser;
    final value = _isSnapchat ? user.snapchatId : user.instagramId;
    return value.replaceAll('@', '').trim();
  }

  void _dismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSocial() async {
    if (_isAnonymous) return;
    if (_handle.isEmpty) {
      AppSnackBar.show(
        context,
        'This match hasn’t added an Instagram or Snapchat handle yet.',
      );
      return;
    }

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

  Future<void> _openSafetyActions(BuildContext context) {
    return showSafetyActions(
      context,
      SafetyTarget.match(match),
      onRemoved: () {
        // The match is gone, so leave its detail screen.
        if (!context.mounted) return;
        if (widget.onDismiss != null) {
          _dismiss();
          return;
        }
        final route = ModalRoute.of(context);
        if (route == null) return;
        if (route.isCurrent) {
          Navigator.of(context).pop();
        } else if (route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      },
    );
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
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 74, 16, 74),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 361),
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
                                  key: const Key('match-reply-card'),
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
                                      const SizedBox(
                                        height: 49,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'It’s a Match!',
                                            style: TextStyle(
                                              fontFamily: TFonts.nunito,
                                              fontSize: 36,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 44,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: _ReplyDescription(
                                            name: name,
                                            choiceText: theme.choiceText,
                                            anonymous: _isAnonymous,
                                          ),
                                        ),
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
                                  centerIcon: Image.asset(
                                    theme.emojiAsset,
                                    width: 36,
                                    height: 36,
                                  ),
                                  plainOtherAvatar: _isAnonymous,
                                ),
                              ),
                            ],
                          ),
                          if (!_isAnonymous) ...[
                            const SizedBox(height: 48),
                            Container(
                              key: const Key('match-social-pill'),
                              width: 84,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: _isSnapchat ? 46 : 0,
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: theme.socialPillColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: Semantics(
                                      label: 'Reply on Instagram',
                                      selected: !_isSnapchat,
                                      button: true,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            _socialAvailable(false)
                                                ? () => setState(
                                                  () =>
                                                      _selectedSnapchat = false,
                                                )
                                                : null,
                                        child: SizedBox(
                                          width: 38,
                                          height: 38,
                                          child: Center(
                                            child: Image.asset(
                                              'assets/icons/insta-outline-white.png',
                                              width: 20,
                                              height: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Semantics(
                                      label: 'Reply on Snapchat',
                                      selected: _isSnapchat,
                                      button: true,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            _socialAvailable(true)
                                                ? () => setState(
                                                  () =>
                                                      _selectedSnapchat = true,
                                                )
                                                : null,
                                        child: SizedBox(
                                          width: 38,
                                          height: 38,
                                          child: Center(
                                            child: Image.asset(
                                              'assets/icons/snap-fill.png',
                                              width: 20,
                                              height: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: SizedBox(
                                key: const Key('match-reply-button'),
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
                                        : 'assets/icons/insta-outline-white.png',
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
                          if (_isAnonymous &&
                              widget.continueWhenUnavailable) ...[
                            const SizedBox(height: 48),
                            SizedBox(
                              width: 305,
                              height: 62,
                              child: ElevatedButton(
                                onPressed: _dismiss,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontFamily: TFonts.nunito,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: _isAnonymous ? 98 : 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 24,
                top: 19,
                child: AppCloseCircleButton(onPressed: _dismiss),
              ),
              // Lines its 36pt circle up with the close button; the extra
              // 6pt on each side is tap target.
              if (widget.showSafetyActions)
                Positioned(
                  left: 18,
                  top: 13,
                  child: SafetyMenuButton(
                    onPressed: () => _openSafetyActions(context),
                    label:
                        _isAnonymous
                            ? 'Hide, report or block this anonymous voter'
                            : 'Report or block $name',
                    iconColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
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
