import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/widgets/emoji_image.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';

class DobScreen extends ConsumerStatefulWidget {
  const DobScreen({super.key});

  @override
  ConsumerState<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends ConsumerState<DobScreen> {
  int _selectedAge = 19;

  static const int _minAge = 13;
  static const int _maxAge = 100;

  FixedExtentScrollController? _ageController;

  @override
  void initState() {
    super.initState();
    final existingDob = ref.read(onboardingDraftProvider).value?.birthday;
    if (existingDob != null) {
      final now = DateTime.now();
      var age = now.year - existingDob.year;
      if (now.month < existingDob.month ||
          (now.month == existingDob.month && now.day < existingDob.day)) {
        age--;
      }
      _selectedAge = age.clamp(_minAge, _maxAge);
    }

    _ageController ??= FixedExtentScrollController(
      initialItem: _selectedAge - _minAge,
    );
  }

  @override
  void dispose() {
    _ageController?.dispose();
    super.dispose();
  }

  DateTime get _selectedBirthday {
    final now = DateTime.now();
    return DateTime(now.year - _selectedAge, now.month, now.day);
  }

  void _onAgeChanged(int index) {
    setState(() {
      _selectedAge = _minAge + index;
    });
  }

  void _incrementAge() {
    if (_selectedAge < _maxAge) {
      _ageController?.animateToItem(
        _selectedAge + 1 - _minAge,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _decrementAge() {
    if (_selectedAge > _minAge) {
      _ageController?.animateToItem(
        _selectedAge - 1 - _minAge,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayAge = _selectedAge.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const DobTopBar(progress: 0.35),
                      const SizedBox(height: 30),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "When's your birthday?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: TColors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const EmojiImage(emoji: '🎂', size: 28),
                      const SizedBox(height: 32),
                      Container(
                        width: 140,
                        height: 116,
                        decoration: BoxDecoration(
                          color: TColors.hammeSurface,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              displayAge,
                              style: const TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w800,
                                fontSize: 52,
                                color: TColors.black,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'years old',
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: TColors.hammePrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 150),
                      SizedBox(
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: TColors.hammeSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    CupertinoTheme(
                      data: const CupertinoThemeData(
                        brightness: Brightness.light,
                      ),
                      child: CupertinoPicker.builder(
                        scrollController:
                            _ageController ??= FixedExtentScrollController(
                              initialItem: _selectedAge - _minAge,
                            ),
                        itemExtent: 44,
                        onSelectedItemChanged: _onAgeChanged,
                        selectionOverlay: const SizedBox.shrink(),
                        squeeze: 1.0,
                        magnification: 1.15,
                        useMagnifier: true,
                        childCount: _maxAge - _minAge + 1,
                        itemBuilder: (context, index) {
                          final age = _minAge + index;
                          final isSelected = age == _selectedAge;
                          return Center(
                            child: Text(
                              age.toString(),
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontSize: isSelected ? 20 : 15,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                color:
                                    isSelected
                                        ? TColors.black
                                        : TColors.darkGrey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 16,
                      child: GestureDetector(
                        onTap: _decrementAge,
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          CupertinoIcons.play_arrow_solid,
                          color: TColors.hammePurpleColor,
                          size: 14,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      child: GestureDetector(
                        onTap: _incrementAge,
                        behavior: HitTestBehavior.opaque,
                        child: const RotatedBox(
                          quarterTurns: 2,
                          child: Icon(
                            CupertinoIcons.play_arrow_solid,
                            color: TColors.hammePurpleColor,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                onTap: () {
                  ref
                      .read(onboardingDraftProvider.notifier)
                      .setBirthday(_selectedBirthday);
                  context.go('/onboarding/name');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
