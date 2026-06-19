import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
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

class _PlayCooldownViewState extends State<PlayCooldownView>
    with SingleTickerProviderStateMixin {
  late Timer _tickTimer;
  late Duration _remaining;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _remaining = _computeRemaining();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final updated = _computeRemaining();
      if (updated.isNegative || updated == Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _tickTimer.cancel();
        widget.onCooldownEnd();
      } else {
        setState(() => _remaining = updated);
      }
    });
  }

  Duration _computeRemaining() {
    if (widget.status.resetAt == null) return Duration.zero;
    final diff = widget.status.resetAt!.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  double get _progress {
    if (widget.status.cooldownMinutes == null || widget.status.cooldownMinutes! <= 0) {
      return 0;
    }
    final totalSeconds = widget.status.cooldownMinutes! * 60;
    return 1.0 - (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final maxCards = widget.status.maxCards ?? 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── Countdown card ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9060FF), Color(0xFFB18DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9060FF).withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing hourglass icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    final scale = 0.9 + 0.1 * _pulseController.value;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: EmojiImage(emoji: '⏳', size: 36),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Slow down!',
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "You've seen $maxCards cards.\nCome back after the timer!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 32),

                // Countdown display
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 56,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),

                const SizedBox(height: 20),

                // Arc progress bar
                SizedBox(
                  width: 200,
                  height: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Next batch unlocks automatically',
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Pro upsell card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0FF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFDDD0FF), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9060FF), Color(0xFFB18DFF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'No limits, ever.',
                      style: TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ProBullet(text: 'Unlimited card views — no waiting'),
                _ProBullet(text: 'Rewind to any card, any time'),
                _ProBullet(text: 'Priority placement in others\' queue'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9060FF), Color(0xFFB18DFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9060FF).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () => context.push('/pro'),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.bolt_fill, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Upgrade to Pro',
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: 0.2,
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
        ],
      ),
    );
  }
}

class _ProBullet extends StatelessWidget {
  const _ProBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓ ', style: TextStyle(color: Color(0xFF9060FF), fontWeight: FontWeight.w900, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF333333),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
