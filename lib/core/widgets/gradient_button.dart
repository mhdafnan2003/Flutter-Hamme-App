import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final double borderRadius;
  final FontWeight fontWeight;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 18,
    this.borderRadius = 40,
    this.fontWeight = FontWeight.w900,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TColors.hammePrimary, TColors.hammePrimaryDark],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: fontWeight,
            fontSize: fontSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
