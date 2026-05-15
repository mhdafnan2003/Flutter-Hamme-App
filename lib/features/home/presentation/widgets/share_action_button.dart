import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class ShareActionButton extends StatelessWidget {
  const ShareActionButton({
    super.key,
    required this.label,
    this.iconPath,
    required this.onTap,
  });

  final String label;
  final String? iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9150FF), Color(0xFF8848F4)],
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconPath != null) ...[
              Image.asset(iconPath!, width: 22, height: 22),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
