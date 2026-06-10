import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

class HammeBottomNavBar extends StatelessWidget {
  const HammeBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.playBadgeCount,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? playBadgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: TColors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: TColors.black,
        unselectedItemColor: TColors.black.withValues(alpha: 0.4),
        selectedLabelStyle: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Opacity(
                opacity: currentIndex == 0 ? 1 : 0.4,
                child: Image.asset(
                  'assets/icons/Outbox Tray.png',
                  width: 26,
                  height: 26,
                ),
              ),
            ),
            label: TTexts.navShare,
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: currentIndex == 1 ? 1 : 0.4,
                    child: Image.asset(
                      'assets/icons/Fire.png',
                      width: 26,
                      height: 26,
                    ),
                  ),
                  if ((playBadgeCount ?? 0) > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0037),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        playBadgeCount! > 99 ? '99+' : '$playBadgeCount',
                        style: const TextStyle(
                          color: TColors.white,
                          fontFamily: TFonts.nunito,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            label: TTexts.navPlay,
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Opacity(
                opacity: currentIndex == 2 ? 1 : 0.4,
                child: Image.asset(
                  'assets/icons/Open Mailbox With Raised Flag.png',
                  width: 26,
                  height: 26,
                ),
              ),
            ),
            label: TTexts.navInbox,
          ),
        ],
      ),
    );
  }
}
