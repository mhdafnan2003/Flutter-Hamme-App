import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _nameError;

  static const double _progress = 120 / 170;

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

  void _onNext() {
    final name = _nameController.text.trim();
    if (name.length < 2 || name.length > 80) {
      setState(() {
        _nameError = 'Display name must be 2 to 80 characters long.';
      });
      return;
    }
    ref.read(onboardingDraftProvider.notifier).setName(name);
    context.go('/onboarding/profile_upload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DobTopBar(
              onBack: () => context.go('/onboarding/dob'),
              progress: _progress,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      const SizedBox(height: 33),
                      const Text(
                        TTexts.nameTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 21),
                      Image.asset(
                        TImages.emojiSpeaking,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 86),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          cursorColor: Colors.black,
                          cursorWidth: 2,
                          cursorHeight: 32,
                          cursorRadius: const Radius.circular(8),
                          textAlign: TextAlign.center,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                          style: const TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w500,
                            fontSize: 24,
                            height: 1,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            hintText: TTexts.nameHint,
                            hintStyle: TextStyle(
                              fontFamily: TFonts.nunito,
                              fontWeight: FontWeight.w500,
                              fontSize: 24,
                              height: 1,
                              color: TColors.hammePlaceholder,
                            ),
                            isDense: true,
                            isCollapsed: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_nameError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _nameError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Text(
              TTexts.nameHelper,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1,
                color: TColors.hammeMutedText,
              ),
            ),
            const SizedBox(height: 17),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                borderRadius: 22,
                fontWeight: FontWeight.w800,
                onTap: _onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
