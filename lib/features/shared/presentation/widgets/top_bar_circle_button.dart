import 'package:flutter/cupertino.dart';
import 'package:hamme_app/utils/constants/colors.dart';

class TopBarCircleButton extends StatelessWidget {
  const TopBarCircleButton({super.key, required this.icon, this.onTap});

  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: TColors.hammeSurface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: icon,
        ),
      ),
    );
  }
}
