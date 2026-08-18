import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/settings_providers.dart';
import '../widgets/settings_page_scaffold.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);

    return SettingsPageScaffold(
      title: 'Notifications',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        children: [
          SettingsSection(
            title: 'Notify me about',
            icon: CupertinoIcons.bell_fill,
            children: [
              SettingsTile(
                icon: CupertinoIcons.heart_fill,
                title: 'New matches',
                subtitle: 'When you and someone else match',
                trailing: Switch.adaptive(
                  value: settings.matches,
                  onChanged: controller.setMatches,
                ),
              ),
              SettingsTile(
                icon: CupertinoIcons.chat_bubble_fill,
                title: 'Messages',
                subtitle: 'New activity in your inbox',
                trailing: Switch.adaptive(
                  value: settings.messages,
                  onChanged: controller.setMessages,
                ),
              ),
              SettingsTile(
                icon: CupertinoIcons.clock_fill,
                title: 'Reminders',
                subtitle: 'Occasional reminders from Hamme',
                trailing: Switch.adaptive(
                  value: settings.reminders,
                  onChanged: controller.setReminders,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
