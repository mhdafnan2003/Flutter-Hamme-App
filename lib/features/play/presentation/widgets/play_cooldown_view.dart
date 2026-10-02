import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/models/play_limit_status.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class PlayCooldownView extends StatefulWidget {
  const PlayCooldownView({
    super.key,
    required this.status,
    required this.onCooldownEnd,
  });

  final PlayLimitStatus status;
  final VoidCallback onCooldownEnd;

  @override
  State<PlayCooldownView> createState() => _PlayCooldownViewState();
}

class _PlayCooldownViewState extends State<PlayCooldownView> {
  // Figma's avatar starts at y=207. With Play's 44 px top bar, the expanded
  // content begins at y=103, leaving 104 px above the avatar.
  static const double _topSpacing = 104;

  late final Timer _tickTimer;
  Timer? _retryTimer;
  late Duration _remaining;
  late final Duration _initialRemaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _initialRemaining = _remaining;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final updated = _computeRemaining();
      if (updated == Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _tickTimer.cancel();
        widget.onCooldownEnd();
        // Still on screen after that means the server still reports the limit
        // (the device clock runs ahead of the server's reset time), so ask
        // again a few times.
        _retryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          if (!mounted || timer.tick > 6) {
            timer.cancel();
            return;
          }
          widget.onCooldownEnd();
        });
        return;
      }

      setState(() => _remaining = updated);
    });
  }

  Duration _computeRemaining() {
    if (widget.status.resetAt == null) return Duration.zero;
    final difference = widget.status.resetAt!.difference(
      DateTime.now().toUtc(),
    );
    return difference.isNegative ? Duration.zero : difference;
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  double get _progress {
    final cooldownMinutes = widget.status.cooldownMinutes;
    // Fall back to the remaining time at first build when the backend
    // doesn't send the cooldown length, so the bar still moves.
    final totalSeconds =
        (cooldownMinutes != null && cooldownMinutes > 0)
            ? cooldownMinutes * 60
            : _initialRemaining.inSeconds;
    if (totalSeconds <= 0) return 0;
    return 1 - (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: _topSpacing),
                _CountdownCard(
                  countdown: _formatDuration(_remaining),
                  progress: _progress,
                ),
                const SizedBox(height: 20),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text:
                            'You’ve seen all free profiles\nYour next match could be in the queue ',
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Image.asset(
                          'assets/icons/emoji_flushed_face.png',
                          width: 16,
                          height: 16,
                          semanticLabel: 'Flushed face',
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.28,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
                const SizedBox(height: 24),
                const _OrDivider(),
                const SizedBox(height: 24),
                _PlayNowButton(onPressed: () => context.push('/pro')),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.countdown, required this.progress});

  final String countdown;
  final double progress;

  static const double _avatarSize = 120;
  static const double _cardTop = 53;
  static const double _cardHeight = 186;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cardTop + _cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Two stacked "deck" cards peeking out behind the main card.
          Positioned(
            top: 22,
            left: 70,
            right: 70,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            top: 34,
            left: 31,
            right: 31,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEBEBEB),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: _cardTop,
            left: 0,
            right: 0,
            child: Container(
              height: _cardHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFEBE5F6),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 40,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Play Again in '),
                        TextSpan(
                          text: countdown,
                          style: const TextStyle(color: Color(0xFFA765FF)),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 21),
                  _CooldownProgress(value: progress),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: SizedBox(
              width: _avatarSize,
              height: _avatarSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Same blurred placeholder shown for anonymous play cards.
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: const CircleAvatar(
                      radius: _avatarSize / 2,
                      backgroundColor: Color(0xFFD7D7D7),
                      child: Icon(
                        CupertinoIcons.person_fill,
                        color: Color(0xFFAAAAAA),
                        size: 58,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/lock.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CooldownProgress extends StatelessWidget {
  const _CooldownProgress({required this.value});

  final double value;

  static const double _width = 105;
  static const double _height = 16;

  @override
  Widget build(BuildContext context) {
    // Never narrower than the track height, so a small value still reads
    // as a rounded pill instead of a sliver.
    final fillWidth =
        value <= 0 ? 0.0 : (value * _width).clamp(_height, _width).toDouble();

    return Container(
      width: _width,
      height: _height,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      // Inner shadow along the top edge of the track.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.black.withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0),
          ],
        ),
      ),
      child: Container(
        width: fillWidth,
        height: _height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: const LinearGradient(
            colors: [Color(0xFF9662FF), Color(0xFFE092FF)],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE9E8FE), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFFB0B1FD),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE9E8FE), thickness: 1)),
      ],
    );
  }
}

class _PlayNowButton extends StatelessWidget {
  const _PlayNowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF9A62FC),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0xFFAF83FD), offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Centred on the whole button, not on the space left between
              // the icon and the pro badge.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 68),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Play Now',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Skip the wait & play now',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.all_inclusive_rounded,
                    color: Color(0xFF6D6D6D),
                    size: 34,
                  ),
                ),
              ),
              Positioned(
                right: 20,
                child: Container(
                  height: 25,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'pro',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1,
                      color: Color(0xFFDC33ED),
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
