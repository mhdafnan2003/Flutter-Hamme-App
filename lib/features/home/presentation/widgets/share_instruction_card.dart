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
    required this.action,
  });

  final String title;
  final int activeStep;
  final int totalSteps;
  final Widget instructionTitle;
  final Widget image;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
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
              fontSize: 22,
              height: 1.2,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          _StepDots(activeStep: activeStep, totalSteps: totalSteps),
          const SizedBox(height: 18),
          instructionTitle,
          const SizedBox(height: 20),
          image,
          const SizedBox(height: 24),
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
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? TColors.hammePrimary : const Color(0xFFE8EDF1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: active ? Colors.white : Colors.black,
            ),
          ),
        );
      }),
    );
  }
}
