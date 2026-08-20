import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/auth_providers.dart';
import '../widgets/settings_page_scaffold.dart';

// Replace these URLs with the final public pages when they are ready.
const privacyPolicyUrl = 'https://www.hamme.app/privacy-policy';
const termsOfUseUrl = 'https://www.hamme.app/terms-of-service';
const safetyResourcesUrl = 'https://www.hamme.app/support';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingAccount = false;

  Future<void> _openExternalLink(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    const deleteMessage =
        'This permanently deletes your profile, photo, matches, and interactions. This cannot be undone. Active App Store subscriptions are not cancelled automatically.';
    final isCupertino =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final confirmed =
        isCupertino
            ? await showCupertinoDialog<bool>(
              context: context,
              builder:
                  (dialogContext) => CupertinoAlertDialog(
                    title: const Text('Delete account?'),
                    content: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(deleteMessage),
                    ),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Delete account'),
                      ),
                    ],
                  ),
            )
            : await showDialog<bool>(
              context: context,
              builder:
                  (dialogContext) => AlertDialog(
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text('Delete account?'),
                    content: const Text(deleteMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Delete account'),
                      ),
                    ],
                  ),
            );
    if (confirmed != true || !mounted) return;

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
            title: 'More',
            icon: CupertinoIcons.house_fill,
            children: [
              SettingsTile(
                icon: CupertinoIcons.checkmark_shield_fill,
                title: 'Safety resources',
                onTap: () => _openExternalLink(context, safetyResourcesUrl),
              ),
              SettingsTile(
                icon: CupertinoIcons.doc_text_fill,
                title: 'Terms of use',
                onTap: () => _openExternalLink(context, termsOfUseUrl),
              ),
              SettingsTile(
                icon: CupertinoIcons.lock_shield_fill,
                title: 'Privacy policy',
                onTap: () => _openExternalLink(context, privacyPolicyUrl),
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
