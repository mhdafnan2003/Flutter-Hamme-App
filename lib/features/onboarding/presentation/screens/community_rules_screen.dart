import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/constants/app_constants.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

import '../../../../../core/widgets/community_rules_summary.dart';
import '../../../../../core/widgets/gradient_button.dart';
import '../widgets/dob_top_bar.dart';

/// Sign-up step where new users must agree to the Terms of Use and Community
/// Guidelines. It comes before any profile details are entered and before
/// the account is created; the agreed version is sent with guest-register.
class CommunityRulesScreen extends ConsumerStatefulWidget {
  const CommunityRulesScreen({super.key});

  @override
  ConsumerState<CommunityRulesScreen> createState() =>
      _CommunityRulesScreenState();
}

class _CommunityRulesScreenState extends ConsumerState<CommunityRulesScreen> {
  static const double _progress = 92 / 170;

  late bool _agreed;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final accepted =
        ref.read(onboardingDraftProvider).value?.termsAcceptedVersion;
    _agreed = accepted != null && accepted >= kCurrentTermsVersion;
  }

  Future<void> _onAgree() async {
    if (!_agreed || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(onboardingDraftProvider.notifier)
          .setTermsAccepted(kCurrentTermsVersion);
      if (mounted) context.go('/onboarding/name');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.white,
      body: SafeArea(
        child: Column(
          children: [
            DobTopBar(
              onBack: () => context.go('/onboarding/dob'),
              progress: _progress,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 33, 24, 12),
                child: const Column(
                  children: [
                    Text(
                      'Hamme community rules',
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
                      'Hamme is for good vibes only. Please read and agree '
                      'before you join.',
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
                onChanged: (value) => setState(() => _agreed = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GradientButton(
                label: 'I agree',
                borderRadius: 22,
                fontWeight: FontWeight.w800,
                onTap: _agreed && !_isSaving ? _onAgree : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
