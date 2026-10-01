import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/routes/route_paths.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/age_picker_wheel.dart';
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
  static const double _progress = 65 / 170;

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
    final ageController =
        _ageController ??= FixedExtentScrollController(
          initialItem: _selectedAge - _minAge,
        );

    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The Figma frame is 393x852. On that reference size these
                  // gaps remain unchanged; on shorter devices they contract
                  // before the page falls back to scrolling.
                  const fixedContentHeight = 350.0;
                  const referenceTrailingSpace = 72.0;
                  const referenceGapTotal = 241.0;
                  final gapScale = ((constraints.maxHeight -
                              fixedContentHeight -
                              referenceTrailingSpace) /
                          referenceGapTotal)
                      .clamp(0.5, 1.2);

                  double gap(double referenceValue) =>
                      referenceValue * gapScale;

                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DobTopBar(
                            progress: _progress,
                            onBack: () {
                              if (context.canPop()) {
                                context.pop();
                              }
                            },
                          ),
                          SizedBox(height: gap(33)),
                          const Text(
                            TTexts.ageTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              height: 1,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: gap(21)),
                          Image.asset(
                            TImages.emojiBirthday,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                          ),
                          SizedBox(height: gap(80)),
                          Container(
                            width: 130,
                            height: 112,
                            decoration: BoxDecoration(
                              color: TColors.hammeSurface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  displayAge,
                                  style: const TextStyle(
                                    fontFamily: TFonts.nunito,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 48,
                                    color: Colors.black,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 13),
                                const Text(
                                  TTexts.yearsOld,
                                  style: TextStyle(
                                    fontFamily: TFonts.nunito,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: TColors.hammeYearsOld,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: gap(107)),
                          AgePickerWheel(
                            controller: ageController,
                            selectedAge: _selectedAge,
                            minAge: _minAge,
                            maxAge: _maxAge,
                            onAgeIndexChanged: _onAgeChanged,
                            onDecrement: _decrementAge,
                            onIncrement: _incrementAge,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                borderRadius: 22,
                fontWeight: FontWeight.w800,
                onTap: () {
                  ref
                      .read(onboardingDraftProvider.notifier)
                      .setBirthday(_selectedBirthday);
                  context.go(RoutePaths.onboardingCommunityRules);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
