import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class FooterLink extends StatelessWidget {
  const FooterLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: TColors.darkGrey,
        ),
      ),
    );
  }
}
