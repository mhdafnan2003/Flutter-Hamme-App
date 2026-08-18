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
    final systemBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomReserve = systemBottomInset < 16 ? 16.0 : systemBottomInset;

    return SizedBox(
      // Figma: 48 px of navigation content + the 34 px iPhone home area.
      height: 48 + bottomReserve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              offset: const Offset(0, -1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _HammeNavItem(
                label: TTexts.navShare,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
                icon: Image.asset(
                  'assets/icons/Outbox Tray.png',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            Expanded(
              child: _HammeNavItem(
                label: TTexts.navPlay,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
                icon: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/icons/Fire.png', width: 24, height: 24),
                    if ((playBadgeCount ?? 0) > 0)
                      Positioned(
                        top: -6,
                        right: -14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0037),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            playBadgeCount! > 99 ? '99+' : '$playBadgeCount',
                            style: const TextStyle(
                              color: TColors.white,
                              fontFamily: TFonts.nunito,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Inbox is intentionally hidden from the bottom navigation for now.
            // The InboxScreen and /inbox route are kept intact for future use.
            // Expanded(
            //   child: _HammeNavItem(
            //     label: TTexts.navInbox,
            //     selected: currentIndex == 2,
            //     onTap: () => onTap(2),
            //     icon: Image.asset(
            //       'assets/icons/Open Mailbox With Raised Flag.png',
            //       width: 24,
            //       height: 24,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _HammeNavItem extends StatelessWidget {
  const _HammeNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = selected ? 1.0 : 0.4;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 6,
              child: Opacity(
                opacity: opacity,
                child: SizedBox(width: 24, height: 24, child: icon),
              ),
            ),
            Positioned(
              top: 34,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: opacity,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 4 / 3,
                    color: TColors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
