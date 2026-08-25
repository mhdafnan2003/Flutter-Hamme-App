import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';

class AgePickerWheel extends StatelessWidget {
  const AgePickerWheel({
    super.key,
    required this.controller,
    required this.selectedAge,
    required this.minAge,
    required this.maxAge,
    required this.onAgeIndexChanged,
    required this.onDecrement,
    required this.onIncrement,
  });

  final FixedExtentScrollController controller;
  final int selectedAge;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onAgeIndexChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  static const double itemExtent = 35;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemExtent * 5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Container(
                height: itemExtent,
                decoration: BoxDecoration(
                  color: TColors.hammePickerHighlight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.light),
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: itemExtent,
              onSelectedItemChanged: onAgeIndexChanged,
              selectionOverlay: const SizedBox.shrink(),
              squeeze: 1.0,
              magnification: 1.0,
              useMagnifier: false,
              childCount: maxAge - minAge + 1,
              itemBuilder: (context, index) {
                return _AgePickerItem(
                  age: minAge + index,
                  selectedAge: selectedAge,
                );
              },
            ),
          ),
          Positioned(
            left: 28,
            child: _PickerChevron(
              pointsRight: true,
              onTap: onDecrement,
            ),
          ),
          Positioned(
            right: 28,
            child: _PickerChevron(
              pointsRight: false,
              onTap: onIncrement,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerChevron extends StatelessWidget {
  const _PickerChevron({
    required this.pointsRight,
    required this.onTap,
  });

  final bool pointsRight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: RotatedBox(
        quarterTurns: pointsRight ? 1 : 3,
        child: SvgPicture.asset(
          TImages.iconPickerChevron,
          width: 12,
          height: 12,
        ),
      ),
    );
  }
}

class _AgePickerItem extends StatelessWidget {
  const _AgePickerItem({
    required this.age,
    required this.selectedAge,
  });

  final int age;
  final int selectedAge;

  @override
  Widget build(BuildContext context) {
    final distance = age - selectedAge;
    final absDistance = distance.abs();
    final isSelected = absDistance == 0;

    Widget label = Text(
      age.toString(),
      style: TextStyle(
        fontFamily: TFonts.nunito,
        fontSize: 20,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
        color: isSelected ? Colors.black : TColors.hammePickerInactive,
        height: 1,
      ),
    );

    if (absDistance >= 2) {
      final fadeDown = distance > 0;
      label = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                fadeDown
                    ? const [TColors.hammePickerInactive, Colors.white]
                    : const [Colors.white, TColors.hammePickerInactive],
          ).createShader(bounds);
        },
        child: label,
      );
    }

    return Center(child: label);
  }
}
