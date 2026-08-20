import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Telegram-style particle veil used in place of readable anonymous text.
class AnimatedSpoiler extends StatefulWidget {
  const AnimatedSpoiler({
    super.key,
    required this.width,
    required this.height,
    required this.particleColor,
    this.backgroundColor = Colors.transparent,
    this.semanticLabel = 'Hidden anonymous identity',
    this.borderRadius,
  });

  final double width;
  final double height;
  final Color particleColor;
  final Color backgroundColor;
  final String semanticLabel;
  final BorderRadius? borderRadius;

  @override
  State<AnimatedSpoiler> createState() => _AnimatedSpoilerState();
}

class _AnimatedSpoilerState extends State<AnimatedSpoiler>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ??
        BorderRadius.circular(math.min(6, widget.height * 0.3));

    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _SpoilerParticlePainter(
              animation: _controller,
              particleColor: widget.particleColor,
              backgroundColor: widget.backgroundColor,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpoilerParticlePainter extends CustomPainter {
  _SpoilerParticlePainter({
    required this.animation,
    required this.particleColor,
    required this.backgroundColor,
    required this.borderRadius,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color particleColor;
  final Color backgroundColor;
  final BorderRadius borderRadius;

  // Stable pseudo-random values prevent the particles jumping between frames.
  double _noise(int seed) {
    final value = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRRect(
      borderRadius.toRRect(bounds),
      Paint()..color = backgroundColor,
    );

    final area = size.width * size.height;
    final particleCount = (area / 8).round().clamp(55, 360);
    final progress = animation.value * math.pi * 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var index = 0; index < particleCount; index++) {
      final x = _noise(index * 3 + 1) * size.width;
      final y = _noise(index * 3 + 2) * size.height;
      final phase = _noise(index * 3 + 3) * math.pi * 2;
      final shimmer = (math.sin(progress + phase) + 1) / 2;
      final radius = 0.55 + (_noise(index * 5 + 7) * 0.8);
      final alpha = 0.22 + (shimmer * 0.68);

      paint.color = particleColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpoilerParticlePainter oldDelegate) {
    return oldDelegate.particleColor != particleColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}
