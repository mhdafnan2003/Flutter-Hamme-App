import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:hamme_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:hamme_app/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings lists preference and external link options', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Safety resources'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('notification controls can be changed', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: NotificationsSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNWidgets(3));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings_match_notifications'), isFalse);
  });

  testWidgets('appearance control changes the selected theme', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppearanceSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('settings_theme_mode'), 'dark');
  });
}
