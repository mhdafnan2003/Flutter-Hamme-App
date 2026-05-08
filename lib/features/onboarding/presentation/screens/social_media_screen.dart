import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';

class SocialMediaScreen extends ConsumerStatefulWidget {
  const SocialMediaScreen({super.key});

  @override
  ConsumerState<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends ConsumerState<SocialMediaScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isInstagramSelected = true;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingDraftProvider).value;
    if (draft != null) {
      if (draft.username != null && draft.username!.isNotEmpty) {
        _usernameController.text = draft.username!;
      }
      if (draft.socialPlatform == TTexts.socialSnapchat) {
        _isInstagramSelected = false;
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
            DobTopBar(
              onBack: () => context.go('/onboarding/profile_upload'),
              progress: 1.0,
              trailing: GestureDetector(
                onTap: () {
                  context.go('/onboarding/pro');
                },
                child: const Text(
                  TTexts.skipAction,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: TColors.darkGrey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              TTexts.socialsTitle,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: TColors.black,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              height: 44,
              width: 282,
              decoration: BoxDecoration(
                color: TColors.hammeSurface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: _isInstagramSelected ? 141 : 3,
                    top: 3,
                    bottom: 3,
                    width: 138,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TColors.borderPrimary,
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              () =>
                                  setState(() => _isInstagramSelected = false),
                          child: Center(
                            child: Text(
                              TTexts.socialSnapchat,
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color:
                                    !_isInstagramSelected
                                        ? TColors.black
                                        : TColors.hammeInactiveText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              () => setState(() => _isInstagramSelected = true),
                          child: Center(
                            child: Text(
                              TTexts.socialInstagram,
                              style: TextStyle(
                                fontFamily: TFonts.nunito,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color:
                                    _isInstagramSelected
                                        ? TColors.black
                                        : TColors.hammeInactiveText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _usernameController,
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
                  hintText: TTexts.usernameHint,
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

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                onTap: () {
                  ref
                      .read(onboardingDraftProvider.notifier)
                      .setSocial(
                        platform:
                            _isInstagramSelected
                                ? TTexts.socialInstagram
                                : TTexts.socialSnapchat,
                        username: _usernameController.text.trim(),
                      );
                  context.go('/onboarding/pro');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
