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

  // Keep the five visible ages close enough together that the values around
  // the default selection (19) don't look artificially spaced out.
  static const double itemExtent = 35;
  static const double wheelHeight = itemExtent * 5;

  @override
  Widget build(BuildContext context) {
    final rowScale = (MediaQuery.textScalerOf(context).scale(20) / 20)
        .clamp(1.0, double.infinity);
    return SizedBox(
      // Match the five complete rows in Figma and clip the neighboring values.
      height: wheelHeight * rowScale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Container(
                height: 35 * rowScale,
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
              itemExtent: itemExtent * rowScale,
              onSelectedItemChanged: onAgeIndexChanged,
              selectionOverlay: const SizedBox.shrink(),
              // A flatter wheel keeps the edge values fully readable.
              diameterRatio: 2.5,
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
            left: 12,
            child: _PickerChevron(pointsRight: true, onTap: onDecrement),
          ),
          Positioned(
            right: 12,
            child: _PickerChevron(pointsRight: false, onTap: onIncrement),
          ),
        ],
      ),
    );
  }
}

class _PickerChevron extends StatelessWidget {
  const _PickerChevron({required this.pointsRight, required this.onTap});

  final bool pointsRight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: RotatedBox(
            quarterTurns: pointsRight ? 1 : 3,
            child: SvgPicture.asset(
              TImages.iconPickerChevron,
              width: 12,
              height: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AgePickerItem extends StatelessWidget {
  const _AgePickerItem({required this.age, required this.selectedAge});

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
        height: 27 / 20,
      ),
    );

    // Figma fades the two values at the visible edges (17 and 21 when 19 is
    // selected) into the white page background.
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
