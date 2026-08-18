import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/settings_page_scaffold.dart';

// Replace these URLs with the final public pages when they are ready.
const privacyPolicyUrl = 'https://example.com/privacy';
const termsOfUseUrl = 'https://example.com/terms';
const safetyResourcesUrl = 'https://example.com/safety';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            ],
          ),
        ],
      ),
    );
  }
}
