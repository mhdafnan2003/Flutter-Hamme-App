import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamme_app/features/matches/presentation/screens/match_reply_screen.dart';
import 'package:hamme_app/models/match_record.dart';

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

  @override
  Widget build(BuildContext context) => MatchReplyScreen(
    match: widget.match,
    currentUserImageUrl: widget.currentUserImageUrl,
    onDismiss: widget.onDismiss,
    continueWhenUnavailable: true,
    showSafetyActions: false,
  );
}
