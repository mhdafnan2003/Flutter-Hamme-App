import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    super.key,
    required this.label,
    required this.color,
    this.showBorder = false,
  });

  final String label;
  final Color color;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border:
            showBorder
                ? Border.all(color: Colors.white, width: 1)
                : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
