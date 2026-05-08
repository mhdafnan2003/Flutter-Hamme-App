import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existingName = ref.read(onboardingDraftProvider).value?.name;
    if (existingName != null && existingName.isNotEmpty) {
      _nameController.text = existingName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DobTopBar(onBack: () => context.go('/onboarding/dob'), progress: 0.5),
            const SizedBox(height: 30),
            const Text(
              TTexts.nameTitle,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: TColors.black,
              ),
            ),
            const SizedBox(height: 12),
            const Text('🗣️', style: TextStyle(fontSize: 28)),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                cursorColor: TColors.black,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  color: TColors.black,
                ),
                decoration: const InputDecoration(
                  hintText: TTexts.nameHint,
                  hintStyle: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w500,
                    fontSize: 24,
                    color: TColors.darkGrey,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            const Spacer(),

            const Text(
              TTexts.nameHelper,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: TColors.hammeMutedText,
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                onTap: () {
                  ref
                      .read(onboardingDraftProvider.notifier)
                      .setName(_nameController.text.trim());
                  context.go('/onboarding/profile_upload');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
