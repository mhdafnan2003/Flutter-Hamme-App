import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double fontSize;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 18,
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
          borderRadius: BorderRadius.circular(40),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
