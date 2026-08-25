import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/text_strings.dart';

import '../../../../../core/widgets/gradient_button.dart';
import '../../../../../core/widgets/onboarding_validation_dialog.dart';
import '../widgets/dob_top_bar.dart';

class SocialMediaScreen extends ConsumerStatefulWidget {
  const SocialMediaScreen({super.key});

  @override
  ConsumerState<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends ConsumerState<SocialMediaScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _isInstagramSelected = true;
  bool _isCreatingAccount = false;

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
    _usernameFocusNode.dispose();
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
                onTap:
                    _isCreatingAccount
                        ? null
                        : () => _createAccountAndOpenPro(
                          'user${DateTime.now().millisecondsSinceEpoch}',
                        ),
                child: const Text(
                  TTexts.skipAction,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1,
                    color: TColors.hammePickerInactive,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      const SizedBox(height: 33),
                      const Text(
                        TTexts.socialsTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 41),
                      SizedBox(
                        height: 40,
                        width: 282,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: TColors.hammeSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                left: _isInstagramSelected ? 144 : 3,
                                top: 3,
                                width: 135,
                                height: 34,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: TColors.borderPrimary,
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap:
                                          () => setState(
                                            () => _isInstagramSelected = false,
                                          ),
                                      child: Center(
                                        child: Text(
                                          TTexts.socialSnapchat,
                                          style: TextStyle(
                                            fontFamily: TFonts.nunito,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            height: 1,
                                            color:
                                                !_isInstagramSelected
                                                    ? Colors.black
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
                                          () => setState(
                                            () => _isInstagramSelected = true,
                                          ),
                                      child: Center(
                                        child: Text(
                                          TTexts.socialInstagram,
                                          style: TextStyle(
                                            fontFamily: TFonts.nunito,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            height: 1,
                                            color:
                                                _isInstagramSelected
                                                    ? Colors.black
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
                      ),
                      const SizedBox(height: 52),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          controller: _usernameController,
                          autofocus: true,
                          cursorColor: Colors.black,
                          cursorWidth: 2,
                          cursorHeight: 32,
                          cursorRadius: const Radius.circular(8),
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9._]'),
                            ),
                          ],
                          onChanged: (_) {
                            final normalized =
                                _usernameController.text.toLowerCase();
                            if (_usernameController.text != normalized) {
                              _usernameController.value = _usernameController
                                  .value
                                  .copyWith(
                                    text: normalized,
                                    selection: TextSelection.collapsed(
                                      offset: normalized.length,
                                    ),
                                  );
                            }
                          },
                          focusNode: _usernameFocusNode,
                          style: const TextStyle(
                            fontFamily: TFonts.nunito,
                            fontWeight: FontWeight.w500,
                            fontSize: 24,
                            height: 1,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            hintText: TTexts.usernameHint,
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
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: TTexts.next,
                borderRadius: 22,
                fontWeight: FontWeight.w800,
                onTap: () async {
                  final username =
                      _usernameController.text.trim().toLowerCase();
                  final usernameRegex = RegExp(r'^[a-z0-9._]+$');
                  if (username.isEmpty) {
                    await _showUsernameError('Enter a username to continue.');
                    return;
                  }
                  if (username.length < 2 || username.length > 30) {
                    await _showUsernameError(
                      'Your username must be 2 to 30 characters long.',
                    );
                    return;
                  }
                  if (!usernameRegex.hasMatch(username)) {
                    await _showUsernameError(
                      'Use lowercase letters, numbers, dots, and underscores only.',
                    );
                    return;
                  }
                  await _createAccountAndOpenPro(username);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAccountAndOpenPro(String username) async {
    if (_isCreatingAccount) return;
    setState(() => _isCreatingAccount = true);

    try {
      final platform =
          _isInstagramSelected ? TTexts.socialInstagram : TTexts.socialSnapchat;
      await ref
          .read(onboardingDraftProvider.notifier)
          .setSocial(platform: platform, username: username);

      final draft = ref.read(onboardingDraftProvider).value;
      if (draft == null) throw Exception('Onboarding data is missing.');

      final age =
          draft.birthday == null
              ? 18
              : (DateTime.now().difference(draft.birthday!).inDays / 365.25)
                  .floor();
      await ref
          .read(authControllerProvider.notifier)
          .guestRegister(
            age: age.clamp(13, 100),
            displayName: (draft.name ?? 'Guest').trim(),
            username: username,
            instagramId: platform == TTexts.socialInstagram ? username : null,
            snapchatId: platform == TTexts.socialSnapchat ? username : null,
          );

      final auth = ref.read(authControllerProvider);
      if (auth.hasError || auth.value == null) {
        throw auth.error ?? Exception('Could not create account.');
      }
      if (mounted) context.go('/onboarding/pro');
    } catch (_) {
      if (mounted) {
        await _showUsernameError('Could not create your account. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isCreatingAccount = false);
    }
  }

  Future<void> _showUsernameError(String message) async {
    HapticFeedback.mediumImpact();
    await showOnboardingValidationDialog(
      context,
      title: 'Choose a username',
      message: message,
      actionLabel: 'Add username',
    );
    if (mounted) _usernameFocusNode.requestFocus();
  }
}
