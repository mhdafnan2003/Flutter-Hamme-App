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
        width: 100,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF606060),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Image.asset(
          iconPath,
          width: 20,
          height: 20,
          color: selected ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
