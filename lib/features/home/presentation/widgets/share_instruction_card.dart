import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class ShareInstructionCard extends StatelessWidget {
  const ShareInstructionCard({
    super.key,
    required this.title,
    required this.activeStep,
    required this.totalSteps,
    required this.instructionTitle,
    required this.image,
    this.imageSpacing = 24,
    required this.action,
  });

  final String title;
  final int activeStep;
  final int totalSteps;
  final Widget instructionTitle;
  final Widget image;
  final double imageSpacing;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(31),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.25,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 7),
          _StepDots(activeStep: activeStep, totalSteps: totalSteps),
          const SizedBox(height: 24),
          instructionTitle,
          SizedBox(height: imageSpacing),
          image,
          const SizedBox(height: 28),
          action,
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.activeStep, required this.totalSteps});

  final int activeStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final step = index + 1;
        final active = step <= activeStep;

        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? TColors.hammeProgressFill : const Color(0xFFE8EDF1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: active ? Colors.white : Colors.black,
            ),
          ),
        );
      }),
    );
  }
}
