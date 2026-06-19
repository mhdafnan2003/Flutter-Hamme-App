import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class HomeStepCard extends StatelessWidget {
  const HomeStepCard({
    required this.title,
    this.subtitle,
    this.child,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: TColors.light,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: TColors.black,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: TColors.textSecondary,
              ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 16),
            child!,
          ],
        ],
      ),
    );
  }
}
