import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class HomeStepCard extends StatelessWidget {
  const HomeStepCard({
    required this.title,
    this.subtitle,
    this.child,
    this.padding = const EdgeInsets.all(24),
    this.subtitleSpacing = 8,
    this.childSpacing = 16,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double subtitleSpacing;
  final double childSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: subtitleSpacing),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle!,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF7B7D82),
                ),
              ),
            ),
          ],
          if (child != null) ...[SizedBox(height: childSpacing), child!],
        ],
      ),
    );
  }
}
