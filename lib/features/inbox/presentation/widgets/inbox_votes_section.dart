import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/features/safety/domain/models/safety_target.dart';
import 'package:hamme_app/features/safety/presentation/widgets/safety_menu_button.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:intl/intl.dart';

/// Whether [vote] is listed in the Inbox for hiding, reporting and blocking.
///
/// Anonymous votes always are: with anonymous vote-back off they never reach
/// Play, so this is the only place to act on them. Named votes are listed
/// once answered; until then they wait in Play, which introduces the voter
/// (and applies the free-play limit) and has its own report control.
bool isInboxManageableVote(InteractionRecord vote) =>
    isAnonymousInteraction(vote) || !isActionablePlayInteraction(vote);

/// Received votes, each with a "•••" button for hide / report / block.
///
/// Rows never show what someone voted, so the list can't be used to force a
/// match in Play.
class InboxVotesSection extends StatefulWidget {
  const InboxVotesSection({
    required this.votes,
    required this.waitingInPlayCount,
    required this.onSafetyActions,
    super.key,
  });

  final List<InteractionRecord> votes;

  /// Named votes left out because they are still waiting in Play.
  final int waitingInPlayCount;
  final ValueChanged<InteractionRecord> onSafetyActions;

  @override
  State<InboxVotesSection> createState() => _InboxVotesSectionState();
}

class _InboxVotesSectionState extends State<InboxVotesSection> {
  static const int _pageSize = 10;
  int _shownCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final votes = widget.votes;
    final shown = votes.take(_shownCount).toList();
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your votes',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap ••• to hide, report or block a vote.',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: TColors.hammeMutedText,
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: TColors.hammeSurface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFE2E3E8),
                    ),
                  _VoteRow(
                    vote: shown[i],
                    now: now,
                    onSafetyActions: () => widget.onSafetyActions(shown[i]),
                  ),
                ],
              ],
            ),
          ),
          if (votes.length > shown.length)
            Center(
              child: TextButton(
                onPressed:
                    () => setState(() => _shownCount += _pageSize * 2),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text(
                  'Show more',
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          if (widget.waitingInPlayCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                widget.waitingInPlayCount == 1
                    ? '1 more vote is waiting for you in Play.'
                    : '${widget.waitingInPlayCount} more votes are waiting '
                        'for you in Play.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: TColors.hammeMutedText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoteRow extends StatelessWidget {
  const _VoteRow({
    required this.vote,
    required this.now,
    required this.onSafetyActions,
  });

  final InteractionRecord vote;
  final DateTime now;
  final VoidCallback onSafetyActions;

  @override
  Widget build(BuildContext context) {
    final anonymous = isAnonymousInteraction(vote);
    final name = _trimmed(vote.fromUserName);
    final username = _trimmed(vote.fromUserUsername)?.replaceFirst('@', '');
    final title =
        anonymous ? 'Anonymous voter' : name ?? username ?? 'Someone';
    final age = _timeAgo(vote.createdAt, now);
    final subtitle =
        !anonymous && name != null && username != null
            ? '@$username · $age'
            : age;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          _VoteAvatar(
            anonymous: anonymous,
            imageUrl: vote.fromUserProfileImageUrl,
            fallbackText: title,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: TColors.hammeMutedText,
                  ),
                ),
              ],
            ),
          ),
          SafetyMenuButton(
            onPressed: onSafetyActions,
            label:
                anonymous
                    ? 'Hide, report or block this anonymous vote'
                    : 'Hide, report or block the vote from $title',
            backgroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _timeAgo(DateTime createdAt, DateTime now) {
    final elapsed = now.difference(createdAt);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
    return DateFormat.MMMd().format(createdAt.toLocal());
  }
}

class _VoteAvatar extends StatelessWidget {
  const _VoteAvatar({
    required this.anonymous,
    required this.imageUrl,
    required this.fallbackText,
  });

  final bool anonymous;
  final String? imageUrl;
  final String fallbackText;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final Widget child;
    if (anonymous) {
      // Same blurred stand-in as anonymous Play cards; never a real photo.
      child = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: const Icon(
          CupertinoIcons.person_fill,
          size: 32,
          color: Color(0xFFAAAAAA),
        ),
      );
    } else if (url != null && url.startsWith('http')) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        width: _size,
        height: _size,
        errorBuilder: (_, __, ___) => _initial(),
      );
    } else {
      child = _initial();
    }

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: anonymous ? const Color(0xFFD7D7D7) : const Color(0xFFAEE5F2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _initial() => Center(
    child: Text(
      fallbackText.characters.firstOrNull?.toUpperCase() ?? '?',
      style: const TextStyle(
        fontFamily: TFonts.nunito,
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: Colors.white,
      ),
    ),
  );
}
