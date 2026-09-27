import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/community_rules.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../providers/auth_providers.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';

/// Shown after the backend reports the account as banned. The local session
/// has already been cleared; acknowledging returns to the start of the app.
class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondaryActionStyle = TextButton.styleFrom(
      foregroundColor: TColors.darkGrey,
      textStyle: const TextStyle(
        fontFamily: TFonts.nunito,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.exclamationmark_shield_fill,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Account suspended',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  CommunityRules.accountSuspendedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: TColors.darkerGrey,
                  ),
                ),
                const Spacer(),
                GradientButton(
                  label: 'Contact support',
                  borderRadius: 22,
                  fontWeight: FontWeight.w800,
                  onTap:
                      () => emailSupport(
                        context,
                        subject: 'Account suspended',
                        body:
                            'I think my Hamme account was suspended by '
                            'mistake.\n\n',
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed:
                          () => openExternalLink(context, kTermsOfUseUrl),
                      style: secondaryActionStyle,
                      child: const Text('Terms of Use'),
                    ),
                    const Text('·', style: TextStyle(color: TColors.darkGrey)),
                    TextButton(
                      // The router leaves this screen once acknowledged.
                      onPressed:
                          () =>
                              ref
                                  .read(accountSuspendedProvider.notifier)
                                  .acknowledge(),
                      style: secondaryActionStyle,
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
