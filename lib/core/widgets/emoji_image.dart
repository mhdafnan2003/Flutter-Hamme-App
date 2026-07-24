import 'package:flutter/material.dart';

/// Renders the device's native emoji glyph.
///
/// Keeping this wrapper lets every existing emoji location share consistent
/// size and alignment without using bundled PNG emoji assets.
class EmojiImage extends StatelessWidget {
  const EmojiImage({
    required this.emoji,
    this.size = 24,
    super.key,
  });

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      emoji,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: size, height: 1),
    );
  }
}
