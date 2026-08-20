import 'dart:async';

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
  late final Timer _tickTimer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final updated = _computeRemaining();
      if (updated == Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _tickTimer.cancel();
        widget.onCooldownEnd();
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
    if (cooldownMinutes == null || cooldownMinutes <= 0) return 0;

    final totalSeconds = cooldownMinutes * 60;
    return 1 - (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final maxCards = widget.status.maxCards ?? 10;

    return LayoutBuilder(
      builder: (context, constraints) {
        final topSpacing = ((constraints.maxHeight - 610) * 0.72).clamp(
          48.0,
          118.0,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                SizedBox(height: topSpacing),
                _CountdownCard(
                  countdown: _formatDuration(_remaining),
                  progress: _progress,
                ),
                const SizedBox(height: 24),
                Text(
                  "You've seen all $maxCards free profiles\n"
                  'Your next match could be in the queue 😳',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.35,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
                const SizedBox(height: 24),
                const _OrDivider(),
                const SizedBox(height: 30),
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 269,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 29,
            left: 72,
            right: 72,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            top: 42,
            left: 35,
            right: 35,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            top: 59,
            left: 0,
            right: 0,
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EAFE),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Spacer(),
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 23),
                  _CooldownProgress(value: progress),
                  const SizedBox(height: 31),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/Rectangle 126.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  Image.asset(
                    'assets/images/lock.png',
                    width: 32,
                    height: 36,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 18,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9B5BFF), Color(0xFFD676F0)],
                ),
              ),
            ),
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
        Expanded(child: Divider(color: Color(0xFFE7E0FF), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFFB2A2FF),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE7E0FF), thickness: 1)),
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
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          colors: [Color(0xFF8752F4), Color(0xFFA25BFF)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF7E47E9), offset: Offset(0, 7)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(27),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.all_inclusive_rounded,
                    color: Color(0xFF777777),
                    size: 37,
                  ),
                ),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Play Now',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Skip the wait & play now',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'pro',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1,
                      color: Color(0xFFC247F1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
