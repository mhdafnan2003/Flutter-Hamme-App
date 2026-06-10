import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/features/shared/presentation/widgets/top_bar_circle_button.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class HammeTopBar extends StatelessWidget {
  const HammeTopBar({super.key, this.onLeftTap, this.onRightTap});

  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          Image.asset(TImages.hammeHomeLogo, height: 30),
          TopBarCircleButton(
            icon: Image.asset(
              'assets/icons/icon_filled/user_3.png',
              width: 20,
              height: 20,
            ),
            onTap: onRightTap,
          ),
        ],
      ),
    );
  }
}
