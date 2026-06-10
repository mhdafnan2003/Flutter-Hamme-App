import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class ProFeature extends StatelessWidget {
  const ProFeature({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: TColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: TColors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: TColors.hammeMutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
