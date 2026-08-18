import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/settings_providers.dart';
import '../widgets/settings_page_scaffold.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);

    return SettingsPageScaffold(
      title: 'Appearance',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        children: [
          SettingsSection(
            title: 'Theme',
            icon: CupertinoIcons.paintbrush_fill,
            children: [
              _ThemeTile(
                icon: CupertinoIcons.device_phone_portrait,
                title: 'System default',
                mode: ThemeMode.system,
                selectedMode: selectedMode,
                onChanged: controller.setThemeMode,
              ),
              _ThemeTile(
                icon: CupertinoIcons.sun_max_fill,
                title: 'Light',
                mode: ThemeMode.light,
                selectedMode: selectedMode,
                onChanged: controller.setThemeMode,
              ),
              _ThemeTile(
                icon: CupertinoIcons.moon_fill,
                title: 'Dark',
                mode: ThemeMode.dark,
                selectedMode: selectedMode,
                onChanged: controller.setThemeMode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.icon,
    required this.title,
    required this.mode,
    required this.selectedMode,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final ThemeMode mode;
  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      onTap: () => onChanged(mode),
      trailing: Icon(
        mode == selectedMode
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.circle,
        color:
            mode == selectedMode ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
