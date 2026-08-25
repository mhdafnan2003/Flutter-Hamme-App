import 'package:flutter/material.dart';
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in subtitle.split('\n'))
                      Text(
                        line,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontFamily: TFonts.nunito,
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D6D6D),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
