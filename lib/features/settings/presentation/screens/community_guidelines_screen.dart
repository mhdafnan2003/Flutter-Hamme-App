import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/community_rules.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';
import '../widgets/settings_page_scaffold.dart';

/// In-app Community Guidelines: what isn't allowed, how to hide, report or
/// block, what happens to reports, and how to reach us. Readable by anyone,
/// including during sign-up and from the terms gate.
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Community Guidelines',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        children: [
          const SettingsSection(
            title: 'Zero tolerance',
            icon: CupertinoIcons.checkmark_shield_fill,
            children: [
              _CardBody([_Paragraph(CommunityRules.zeroToleranceStatement)]),
            ],
          ),
          const SizedBox(height: 32),
          const SettingsSection(
            title: 'Not allowed on Hamme',
            icon: CupertinoIcons.nosign,
            children: [
              _CardBody([
                _BulletList(CommunityRules.prohibitedContent),
                _Paragraph(
                  'These rules apply everywhere on Hamme, including your '
                  'name, username, profile photo, and linked social handles.',
                  muted: true,
                ),
              ]),
            ],
          ),
          const SizedBox(height: 32),
          const SettingsSection(
            title: 'Hide, report, or block',
            icon: CupertinoIcons.flag_fill,
            children: [
              _CardBody([
                _Paragraph(
                  'Every vote card and match has a report option — including '
                  'anonymous votes. From there you can:',
                ),
                _BulletList([
                  'Hide it: it disappears from your feed right away.',
                  "Report it: tell us what's wrong so our team can review it.",
                  'Block the sender: they can no longer vote for you or '
                      'match with you, even anonymously.',
                ]),
                _Paragraph(
                  "You can review the people you've blocked in Settings.",
                  muted: true,
                ),
              ]),
            ],
          ),
          const SizedBox(height: 32),
          const SettingsSection(
            title: 'What happens next',
            icon: CupertinoIcons.clock_fill,
            children: [
              _CardBody([
                _BulletList([
                  CommunityRules.reviewPromise,
                  'Content that breaks these rules is removed.',
                  'The account responsible is banned from Hamme.',
                ]),
              ]),
            ],
          ),
          const SizedBox(height: 32),
          SettingsSection(
            title: 'Contact us',
            icon: CupertinoIcons.envelope_fill,
            children: [
              const _CardBody([
                _Paragraph(
                  'Questions, feedback, or a safety concern? Email us any '
                  'time.',
                ),
              ]),
              SettingsTile(
                icon: CupertinoIcons.envelope_fill,
                title: 'Email Hamme support',
                subtitle: kSupportEmail,
                onTap: () => emailSupport(context, subject: 'Hamme support'),
              ),
              SettingsTile(
                icon: CupertinoIcons.doc_text_fill,
                title: 'Terms of use',
                onTap: () => openExternalLink(context, kTermsOfUseUrl),
              ),
              SettingsTile(
                icon: CupertinoIcons.globe,
                title: 'Guidelines on the web',
                onTap: () => openExternalLink(context, kCommunityGuidelinesUrl),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _EmergencyNotice(),
        ],
      ),
    );
  }
}

/// Padded content of one guidelines card.
class _CardBody extends StatelessWidget {
  const _CardBody(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: children,
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: TFonts.nunito,
        fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
        fontSize: muted ? 14 : 16,
        height: 1.4,
        color: muted ? TColors.darkGrey : null,
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      children: [
        for (final item in items)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(
                  CupertinoIcons.circle_fill,
                  size: 7,
                  color: TColors.hammePrimaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmergencyNotice extends StatelessWidget {
  const _EmergencyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Colors.redAccent,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              CommunityRules.emergencyNotice,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
