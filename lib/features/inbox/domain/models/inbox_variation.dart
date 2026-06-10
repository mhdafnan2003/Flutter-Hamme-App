import 'package:flutter/material.dart';

class InboxVariation {
  const InboxVariation({
    required this.gradientColors,
    required this.borderColor,
    required this.emoji,
    required this.typeKey,
    required this.tagline,
  });

  final List<Color> gradientColors;
  final Color borderColor;
  final String emoji;
  final String typeKey;
  final String tagline;
}
