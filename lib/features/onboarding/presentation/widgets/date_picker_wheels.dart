import 'package:flutter/cupertino.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class DatePickerWheels extends StatelessWidget {
  final int maxDay;
  final int selectedDay;
  final int selectedMonth;
  final int selectedYear;
  final int startYear;
  final int endYear;
  final List<String> months;
  final FixedExtentScrollController dayController;
  final FixedExtentScrollController monthController;
  final FixedExtentScrollController yearController;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const DatePickerWheels({
    super.key,
    required this.maxDay,
    required this.selectedDay,
    required this.selectedMonth,
    required this.selectedYear,
    required this.startYear,
    required this.endYear,
    required this.months,
    required this.dayController,
    required this.monthController,
    required this.yearController,
    required this.onDayChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          child: IgnorePointer(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: TColors.hammeSurface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          child: const RotatedBox(
            quarterTurns: 2,
            child: Icon(
              CupertinoIcons.play_arrow_solid,
              color: TColors.hammeAccentBlue,
              size: 14,
            ),
          ),
        ),
        Positioned(
          right: 16,
          child: const Icon(
            CupertinoIcons.play_arrow_solid,
            color: TColors.hammeAccentBlue,
            size: 14,
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: WheelColumn(
                controller: dayController,
                itemCount: maxDay,
                selectedIndex: selectedDay - 1,
                labelBuilder: (i) => '${i + 1}',
                onChanged: onDayChanged,
              ),
            ),
            Expanded(
              flex: 4,
              child: WheelColumn(
                controller: monthController,
                itemCount: months.length,
                selectedIndex: selectedMonth,
                labelBuilder: (i) => months[i],
                onChanged: onMonthChanged,
              ),
            ),
            Expanded(
              flex: 3,
              child: WheelColumn(
                controller: yearController,
                itemCount: endYear - startYear + 1,
                selectedIndex: selectedYear - startYear,
                labelBuilder: (i) => '${startYear + i}',
                onChanged: onYearChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WheelColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedIndex;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;

  const WheelColumn({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.selectedIndex,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.light),
      child: CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: 44,
        onSelectedItemChanged: onChanged,
        selectionOverlay: const SizedBox.shrink(),
        squeeze: 1.0,
        magnification: 1.15,
        useMagnifier: true,
        childCount: itemCount,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return Center(
            child: Text(
              labelBuilder(index),
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontSize: isSelected ? 17 : 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? TColors.black : TColors.darkGrey,
              ),
            ),
          );
        },
      ),
    );
  }
}
