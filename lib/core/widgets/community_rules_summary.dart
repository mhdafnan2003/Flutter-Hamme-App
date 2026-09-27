import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_paths.dart';
import '../../utils/constants/colors.dart';
import '../../utils/constants/fonts.dart';
import '../constants/app_constants.dart';
import '../constants/community_rules.dart';
import '../utils/link_launcher.dart';

/// The zero-tolerance statement and key rules shown on the agreement screens
/// (sign-up step and terms gate). Styled for those light, full-screen pages.
class CommunityRulesSummary extends StatelessWidget {
  const CommunityRulesSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TColors.hammeSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            CommunityRules.zeroToleranceStatement,
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.4,
              color: TColors.black,
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (final rule in CommunityRules.keyRules)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    CupertinoIcons.checkmark_shield_fill,
                    size: 20,
                    color: TColors.hammePrimaryDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rule,
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.3,
                      color: TColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Links to the full Terms of Use, Privacy Policy and Community Guidelines.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        _LegalLink(
          label: 'Terms of Use',
          onTap: () => openExternalLink(context, kTermsOfUseUrl),
        ),
        _LegalLink(
          label: 'Privacy Policy',
          onTap: () => openExternalLink(context, kPrivacyPolicyUrl),
        ),
        _LegalLink(
          label: 'Community Guidelines',
          onTap: () => context.push(RoutePaths.communityGuidelines),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: TColors.hammePrimaryDark,
        textStyle: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(label),
    );
  }
}

/// The required "I agree" checkbox. The whole row is tappable.
class TermsAgreementCheckbox extends StatelessWidget {
  const TermsAgreementCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged:
                  onChanged == null
                      ? null
                      : (checked) => onChanged(checked ?? false),
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected)
                        ? TColors.hammePrimaryDark
                        : Colors.transparent,
              ),
              side: const BorderSide(color: TColors.hammePrimaryDark, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                CommunityRules.agreementLabel,
                style: TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: TColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
