import 'package:flutter/material.dart';

class InboxVariation {
  const InboxVariation({
    required this.gradientColors,
    required this.borderColor,
    required this.emoji,
    required this.typeKey,
  });

  final List<Color> gradientColors;
  final Color borderColor;
  final String emoji;
  final String typeKey;
}
