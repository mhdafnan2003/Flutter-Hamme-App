import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/data/datasources/profile_remote_data_source.dart';
import 'api_providers.dart';

const _themeModeKey = 'settings_theme_mode';
const _matchNotificationsKey = 'settings_match_notifications';
const _messageNotificationsKey = 'settings_message_notifications';
const _reminderNotificationsKey = 'settings_reminder_notifications';
// The account whose notification change hasn't reached the server yet.
const _notificationsPendingUserKey = 'settings_notifications_pending_user';

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

  /// The settings as the server names them (`messages` covers new votes).
  Map<String, bool> toJson() => {
    'matches': matches,
    'messages': messages,
    'reminders': reminders,
  };
}

/// The notification switches. Kept on this device so the screen shows them
/// at once, and on the server, which skips the pushes that are off.
class NotificationSettingsController
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsController(this._ref)
    : super(const NotificationSettings()) {
    _loaded = _load();
  }

  final Ref _ref;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = NotificationSettings(
      matches: preferences.getBool(_matchNotificationsKey) ?? true,
      messages: preferences.getBool(_messageNotificationsKey) ?? true,
      reminders: preferences.getBool(_reminderNotificationsKey) ?? true,
    );
  }

  Future<void> setMatches(bool value) =>
      _update(state.copyWith(matches: value), {'matches': value});

  Future<void> setMessages(bool value) =>
      _update(state.copyWith(messages: value), {'messages': value});

  Future<void> setReminders(bool value) =>
      _update(state.copyWith(reminders: value), {'reminders': value});

  /// Shows the server's settings (they may have been changed on another
  /// device), or first sends a change that couldn't reach the server earlier.
  Future<void> syncWithServer() async {
    await _loaded;
    if (await _hasPendingChange()) {
      await _saveToServer(state.toJson());
      return;
    }
    try {
      final server = await _remote.getNotificationSettings();
      if (!mounted || server.isEmpty) return;
      state = state.copyWith(
        matches: server['matches'],
        messages: server['messages'],
        reminders: server['reminders'],
      );
      await _saveLocally(state);
    } catch (error) {
      debugPrint('[Settings] could not load notification settings: $error');
    }
  }

  /// Sends a change that couldn't reach the server earlier (e.g. made
  /// offline), so pushes the user turned off stop.
  Future<void> retryPendingChange() async {
    await _loaded;
    if (await _hasPendingChange()) await _saveToServer(state.toJson());
  }

  ProfileRemoteDataSource get _remote =>
      ProfileRemoteDataSource(_ref.read(apiServiceProvider));

  Future<void> _update(
    NotificationSettings settings,
    Map<String, bool> change,
  ) async {
    state = settings;
    await _saveLocally(settings);
    // Only the changed switch: quick changes to different switches then
    // can't overwrite each other on the server.
    await _saveToServer(change);
  }

  Future<void> _saveLocally(NotificationSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_matchNotificationsKey, settings.matches);
    await preferences.setBool(_messageNotificationsKey, settings.messages);
    await preferences.setBool(_reminderNotificationsKey, settings.reminders);
  }

  Future<void> _saveToServer(Map<String, bool> changes) async {
    try {
      await _remote.updateNotificationSettings(changes);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_notificationsPendingUserKey);
    } catch (error) {
      debugPrint('[Settings] notification settings not saved yet: $error');
      // Keep the change on this device and send all settings again later,
      // for this account only.
      try {
        final userId = await _ref.read(apiServiceProvider).sessionUserId();
        if (userId == null) return;
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_notificationsPendingUserKey, userId);
      } catch (_) {}
    }
  }

  Future<bool> _hasPendingChange() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final pendingUserId = preferences.getString(_notificationsPendingUserKey);
      if (pendingUserId == null) return false;
      return pendingUserId ==
          await _ref.read(apiServiceProvider).sessionUserId();
    } catch (_) {
      return false;
    }
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
    );

/// Sends a notification change that couldn't reach the server (e.g. made
/// offline) once the signed-in app is back. Kept alive by the main tab shell.
final notificationSettingsRetryProvider = Provider<void>((ref) {
  unawaited(
    ref.read(notificationSettingsProvider.notifier).retryPendingChange(),
  );
});
