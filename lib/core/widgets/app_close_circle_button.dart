import 'package:flutter/material.dart';

class AppCloseCircleButton extends StatelessWidget {
  const AppCloseCircleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: 0.6,
          child: Image.asset(
            'assets/images/Close_circle.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
