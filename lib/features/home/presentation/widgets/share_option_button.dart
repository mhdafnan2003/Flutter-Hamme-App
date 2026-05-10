import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class ShareOptionButton extends StatelessWidget {
  const ShareOptionButton({
    super.key,
    required this.text,
    required this.emoji,
    required this.colors,
  });

  final String text;
  final String emoji;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
