import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/features/shared/presentation/widgets/top_bar_circle_button.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class HammeTopBar extends StatelessWidget {
  const HammeTopBar({
    super.key,
    this.onLeftTap,
    this.onRightTap,
    this.isPro = false,
  });

  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TopBarCircleButton(icon: CupertinoIcons.doc_on_doc, onTap: onLeftTap),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(TImages.hammeHomeLogo, height: 30),
              if (isPro)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: TColors.hammePrimaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          TopBarCircleButton(
            icon: CupertinoIcons.person_solid,
            onTap: onRightTap,
          ),
        ],
      ),
    );
  }
}
