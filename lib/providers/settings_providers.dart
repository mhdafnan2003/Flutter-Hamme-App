import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'settings_theme_mode';
const _matchNotificationsKey = 'settings_match_notifications';
const _messageNotificationsKey = 'settings_message_notifications';
const _reminderNotificationsKey = 'settings_reminder_notifications';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    state = switch (preferences.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (_) => ThemeModeController(),
);

@immutable
class NotificationSettings {
  const NotificationSettings({
    this.matches = true,
    this.messages = true,
    this.reminders = true,
  });

  final bool matches;
  final bool messages;
  final bool reminders;

  NotificationSettings copyWith({
    bool? matches,
    bool? messages,
    bool? reminders,
  }) {
    return NotificationSettings(
      matches: matches ?? this.matches,
      messages: messages ?? this.messages,
      reminders: reminders ?? this.reminders,
    );
  }
}

class NotificationSettingsController
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsController() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    state = NotificationSettings(
      matches: preferences.getBool(_matchNotificationsKey) ?? true,
      messages: preferences.getBool(_messageNotificationsKey) ?? true,
      reminders: preferences.getBool(_reminderNotificationsKey) ?? true,
    );
  }

  Future<void> setMatches(bool value) async {
    state = state.copyWith(matches: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_matchNotificationsKey, value);
  }

  Future<void> setMessages(bool value) async {
    state = state.copyWith(messages: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_messageNotificationsKey, value);
  }

  Future<void> setReminders(bool value) async {
    state = state.copyWith(reminders: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reminderNotificationsKey, value);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsController, NotificationSettings>(
      (_) => NotificationSettingsController(),
    );
