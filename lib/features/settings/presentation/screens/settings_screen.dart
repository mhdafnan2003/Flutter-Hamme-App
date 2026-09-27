import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/community_rules.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../providers/auth_providers.dart';
import '../../../../routes/route_paths.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/settings_page_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingAccount = false;

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final confirmed = await confirmAccountDeletion(context);
    if (!confirmed || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete your account. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  /// Account details appended to support emails so we can find the profile.
  String _accountDetails() {
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    final platform = switch (Theme.of(context).platform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      final other => other.name,
    };
    return [
      '---',
      'Please keep these details so we can find your account:',
      if (user != null && user.shareCode.isNotEmpty)
        'Share code: ${user.shareCode}',
      if (user != null) 'User ID: ${user.id}',
      'Platform: $platform',
    ].join('\n');
  }

  void _contactSupport() {
    emailSupport(
      context,
      subject: 'Hamme support',
      body: '\n\n${_accountDetails()}',
    );
  }

  void _reportSafetyConcern() {
    emailSupport(
      context,
      subject: 'Safety report',
      body:
          'What happened? Tell us who was involved, when it happened, and '
          'where in the app you saw it.\n\n\n${_accountDetails()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        children: [
          SettingsSection(
            title: 'Preferences',
            icon: CupertinoIcons.star_fill,
            children: [
              SettingsTile(
                icon: CupertinoIcons.bell_fill,
                title: 'Notifications',
                onTap: () => context.push('/settings/notifications'),
              ),
              SettingsTile(
                icon: CupertinoIcons.moon_fill,
                title: 'Appearance',
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SettingsSection(
            title: 'Safety & support',
            icon: CupertinoIcons.shield_lefthalf_fill,
            children: [
              SettingsTile(
                icon: CupertinoIcons.person_3_fill,
                title: 'Community Guidelines',
                onTap: () => context.push(RoutePaths.communityGuidelines),
              ),
              SettingsTile(
                icon: CupertinoIcons.hand_raised_fill,
                title: 'Blocked users',
                onTap: () => context.push(RoutePaths.blockedUsers),
              ),
              SettingsTile(
                icon: CupertinoIcons.envelope_fill,
                title: 'Contact us',
                subtitle: kSupportEmail,
                onTap: _contactSupport,
              ),
              SettingsTile(
                icon: CupertinoIcons.exclamationmark_bubble_fill,
                title: 'Report a safety concern',
                subtitle: CommunityRules.reviewPromise,
                onTap: _reportSafetyConcern,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Text(
              'You can also email $kSupportEmail any time. '
              '${CommunityRules.emergencyNotice}',
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: TColors.darkGrey,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SettingsSection(
            title: 'More',
            icon: CupertinoIcons.house_fill,
            children: [
              SettingsTile(
                icon: CupertinoIcons.checkmark_shield_fill,
                title: 'Safety resources',
                onTap: () => openExternalLink(context, kSafetyResourcesUrl),
              ),
              SettingsTile(
                icon: CupertinoIcons.doc_text_fill,
                title: 'Terms of use',
                onTap: () => openExternalLink(context, kTermsOfUseUrl),
              ),
              SettingsTile(
                icon: CupertinoIcons.lock_shield_fill,
                title: 'Privacy policy',
                onTap: () => openExternalLink(context, kPrivacyPolicyUrl),
              ),
              SettingsTile(
                icon: CupertinoIcons.trash_fill,
                title: 'Delete account',
                foregroundColor: Colors.redAccent,
                onTap: _isDeletingAccount ? null : _deleteAccount,
                trailing:
                    _isDeletingAccount
                        ? const CupertinoActivityIndicator()
                        : const Icon(
                          CupertinoIcons.chevron_right,
                          color: Colors.redAccent,
                          size: 22,
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
