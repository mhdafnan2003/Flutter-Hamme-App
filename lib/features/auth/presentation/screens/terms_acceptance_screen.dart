import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/community_rules_summary.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/onboarding_validation_dialog.dart';
import '../../../../providers/auth_providers.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../settings/presentation/widgets/delete_account_dialog.dart';
import 'package:hamme_app/utils/popups/app_snack_bar.dart';

/// Blocking gate for signed-in users who haven't agreed to the current Terms
/// of Use and Community Guidelines (accounts created before the agreement
/// step existed). The router keeps them here until they agree, log out, or
/// delete their account.
class TermsAcceptanceScreen extends ConsumerStatefulWidget {
  const TermsAcceptanceScreen({super.key});

  @override
  ConsumerState<TermsAcceptanceScreen> createState() =>
      _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends ConsumerState<TermsAcceptanceScreen> {
  bool _agreed = false;
  bool _isSaving = false;
  bool _isLeaving = false;

  bool get _isBusy => _isSaving || _isLeaving;

  Future<void> _accept() async {
    if (!_agreed || _isBusy) return;
    setState(() => _isSaving = true);
    try {
      // Once the session records the acceptance the router moves on to Home.
      await ref.read(authControllerProvider.notifier).acceptCurrentTerms();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logOut() async {
    if (_isBusy) return;
    final confirmed = await showOnboardingValidationDialog(
      context,
      title: 'Log out?',
      message:
          'You need to agree to the community rules to keep using Hamme. '
          "If you log out, you'll need to set up Hamme again to use it.",
      actionLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLeaving = true);
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isBusy) return;
    final confirmed = await confirmAccountDeletion(context);
    if (!confirmed || !mounted) return;
    setState(() => _isLeaving = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'Could not delete your account. Please try again.',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondaryActionStyle = TextButton.styleFrom(
      foregroundColor: TColors.darkGrey,
      textStyle: const TextStyle(
        fontFamily: TFonts.nunito,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TColors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Image.asset(TImages.hammeHomeLogo, height: 32),
              ),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Column(
                    children: [
                      Text(
                        'Our community rules',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'To keep using Hamme, please review and agree to our '
                        'Terms of Use and Community Guidelines.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TFonts.nunito,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: TColors.hammeMutedText,
                        ),
                      ),
                      SizedBox(height: 24),
                      CommunityRulesSummary(),
                      SizedBox(height: 4),
                      LegalLinks(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 24, 8),
                child: TermsAgreementCheckbox(
                  value: _agreed,
                  onChanged:
                      _isBusy
                          ? null
                          : (value) => setState(() => _agreed = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GradientButton(
                  label: _isSaving ? 'Saving…' : 'I agree',
                  borderRadius: 22,
                  fontWeight: FontWeight.w800,
                  onTap: _agreed && !_isBusy ? _accept : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isBusy ? null : _logOut,
                      style: secondaryActionStyle,
                      child: const Text('Log out'),
                    ),
                    const Text('·', style: TextStyle(color: TColors.darkGrey)),
                    TextButton(
                      onPressed: _isBusy ? null : _deleteAccount,
                      style: secondaryActionStyle,
                      child: const Text('Delete account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
