import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../utils/constants/colors.dart';

/// Round button that opens the hide / report / block options for an item.
///
/// Draws a [diameter] circle inside a 48×48 tap target, above Apple's 44pt
/// minimum, so it is easy to find and hit on every card and row.
class SafetyMenuButton extends StatelessWidget {
  const SafetyMenuButton({
    required this.onPressed,
    this.label = 'Hide, report or block',
    this.icon = CupertinoIcons.ellipsis,
    this.iconAsset,
    this.iconColor = Colors.black87,
    this.backgroundColor = TColors.hammeSurface,
    this.diameter = 36,
    this.iconSize = 20,
    super.key,
  });

  final VoidCallback onPressed;

  /// Tooltip and screen-reader label.
  final String label;
  final IconData icon;
  final String? iconAsset;
  final Color iconColor;
  final Color backgroundColor;
  final double diameter;
  final double iconSize;

  static const double tapTargetSize = 48;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(tapTargetSize),
        pressedOpacity: 0.5,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child:
              iconAsset != null
                  ? Image.asset(
                    iconAsset!,
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    color: iconColor,
                    semanticLabel: label,
                  )
                  : Icon(
                    icon,
                    size: iconSize,
                    color: iconColor,
                    semanticLabel: label,
                  ),
        ),
      ),
    );
  }
}
