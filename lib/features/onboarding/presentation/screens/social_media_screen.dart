import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/core/utils/content_filter.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/routes/route_paths.dart';
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

  /// Inline error under the handle field (content filter / server rejection).
  String? _usernameError;

  ContentFilterField get _handleField =>
      _isInstagramSelected
          ? ContentFilterField.instagram
          : ContentFilterField.snapchat;

  void _selectPlatform({required bool instagram}) {
    setState(() {
      _isInstagramSelected = instagram;
      _usernameError = null;
    });
  }

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
                    color: TColors.hammePickerInactive,
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Preserve Figma's keyboard-open spacing at 393x852. On
                  // shorter screens, contract whitespace before scrolling.
                  const fixedContentHeight = 88.0;
                  const referenceTrailingSpace = 102.0;
                  const referenceGapTotal = 126.0;
                  final gapScale = ((constraints.maxHeight -
                              fixedContentHeight -
                              referenceTrailingSpace) /
                          referenceGapTotal)
                      .clamp(0.45, 1.0);

                  double gap(double referenceValue) =>
                      referenceValue * gapScale;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          SizedBox(height: gap(33)),
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
                          SizedBox(height: gap(38)),
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
                                              () => _selectPlatform(
                                                instagram: false,
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
                                                        : TColors
                                                            .hammeInactiveText,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap:
                                              () => _selectPlatform(
                                                instagram: true,
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
                                                        : TColors
                                                            .hammeInactiveText,
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
                          SizedBox(height: gap(55)),
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
                                if (_usernameError != null) {
                                  setState(() => _usernameError = null);
                                }
                                final normalized =
                                    _usernameController.text.toLowerCase();
                                if (_usernameController.text != normalized) {
                                  _usernameController.value =
                                      _usernameController.value.copyWith(
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
                          if (_usernameError != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                _usernameError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: TFonts.nunito,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
                  final filterError = ContentFilter.validate(
                    username,
                    _handleField,
                  );
                  if (filterError != null) {
                    _showInlineUsernameError(filterError);
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

      // Nobody gets an account without agreeing to the community rules
      // (e.g. an onboarding draft saved by an older app version).
      final acceptedTerms = draft.termsAcceptedVersion;
      if (acceptedTerms == null || acceptedTerms < kCurrentTermsVersion) {
        if (mounted) context.go(RoutePaths.onboardingCommunityRules);
        return;
      }

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
            acceptedTermsVersion: acceptedTerms,
          );

      final auth = ref.read(authControllerProvider);
      if (auth.hasError || auth.valueOrNull == null) {
        throw auth.error ?? Exception('Could not create account.');
      }
      if (mounted) context.go('/onboarding/pro');
    } catch (error) {
      if (!mounted) return;
      // A banned device is sent to the suspension notice by the router.
      if (error is AppException && error.isAccountBanned) return;
      if (error is AppException && error.isObjectionableContent) {
        await _showRejectedContent(error);
        return;
      }
      await _showUsernameError('Could not create your account. Try again.');
    } finally {
      if (mounted) setState(() => _isCreatingAccount = false);
    }
  }

  /// The server's content filter rejected a field: show its message where
  /// the user can fix it.
  Future<void> _showRejectedContent(AppException error) async {
    final field = error.field;
    if (field == 'name' || field == 'displayName') {
      // The name was entered on an earlier step.
      HapticFeedback.mediumImpact();
      final editName = await showOnboardingValidationDialog(
        context,
        title: 'Choose another name',
        message: error.message,
        actionLabel: 'Edit name',
      );
      if (editName && mounted) context.go('/onboarding/name');
      return;
    }
    _showInlineUsernameError(error.message);
  }

  void _showInlineUsernameError(String message) {
    HapticFeedback.mediumImpact();
    setState(() => _usernameError = message);
    _usernameFocusNode.requestFocus();
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
