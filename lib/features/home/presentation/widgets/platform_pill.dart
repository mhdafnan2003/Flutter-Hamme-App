import 'package:flutter/material.dart';

class PlatformPill extends StatelessWidget {
  const PlatformPill({
    super.key,
    required this.selected,
    required this.iconPath,
    required this.onTap,
  });

  final bool selected;
  final String iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF606060),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Image.asset(
            iconPath,
            width: 24,
            height: 24,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
