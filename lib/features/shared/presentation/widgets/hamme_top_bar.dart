import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/shared/presentation/widgets/top_bar_circle_button.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class HammeTopBar extends StatelessWidget {
  const HammeTopBar({
    super.key,
    this.onLeftTap,
    this.onRightTap,
    this.verticalPadding = 12,
  });

  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: verticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TopBarCircleButton(
            icon: Image.asset(
              'assets/icons/icon_filled/Copy.png',
              width: 20,
              height: 20,
            ),
            onTap: onLeftTap ?? () => context.push('/matches'),
          ),
          const HammeWordmark(),
          TopBarCircleButton(
            icon: Image.asset(
              'assets/icons/icon_filled/user_3.png',
              width: 22,
              height: 22,
            ),
            onTap: onRightTap ?? () => context.push('/profile'),
          ),
        ],
      ),
    );
  }
}

class HammeWordmark extends StatelessWidget {
  const HammeWordmark({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text(
        'Hamme',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: TFonts.nunito,
          fontSize: 24,
          height: 1.375,
          fontWeight: FontWeight.w800,
          foreground:
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8
                ..color = const Color(0xFFA678FF),
        ),
      ),
      const Text(
        'Hamme',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: TFonts.nunito,
          fontSize: 24,
          height: 1.375,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    ],
  );
}
