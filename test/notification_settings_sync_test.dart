import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/services/api_service.dart';
import 'package:hamme_app/core/services/secure_storage_service.dart';
import 'package:hamme_app/features/interactions/data/datasources/interaction_remote_data_source.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/settings_providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An access token whose `sub` is [userId] (only decoded locally).
String _accessTokenFor(String userId) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': userId})}.signature';
}

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request request) respond;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.loadFromString(envString: 'API_BASE_URL=http://example.test/api/v1');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'access_token': _accessTokenFor('user-1'),
    });
    requests = [];
    respond =
        (_) => http.Response(
          jsonEncode({
            'notifications': {
              'matches': true,
              'messages': true,
              'reminders': true,
            },
          }),
          200,
        );
  });

  ApiService api() {
    return ApiService(
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
      storage: SecureStorageService(const FlutterSecureStorage()),
    );
  }

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(api())],
    );
    addTearDown(container.dispose);
    return container;
  }

  Object? body(http.Request request) =>
      request.body.isEmpty ? null : jsonDecode(request.body);

  test('a changed switch is saved on the device and on the server', () async {
    final settings = container().read(notificationSettingsProvider.notifier);

    await settings.setMessages(false);

    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/api/v1/profiles/me/notifications');
    expect(body(requests.single), {'messages': false});
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings_message_notifications'), isFalse);
  });

  test('opening the screen shows the server settings', () async {
    respond =
        (_) => http.Response(
          jsonEncode({
            'notifications': {
              'matches': false,
              'messages': true,
              'reminders': false,
            },
          }),
          200,
        );
    final container = this.container();

    await container.read(notificationSettingsProvider.notifier).syncWithServer();

    expect(requests.single.method, 'GET');
    final state = container.read(notificationSettingsProvider);
    expect([state.matches, state.messages, state.reminders], [
      false,
      true,
      false,
    ]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings_match_notifications'), isFalse);
  });

  test('a change that could not be sent is sent again later', () async {
    respond = (_) => http.Response(jsonEncode({'message': 'down'}), 503);
    final container = this.container();
    final settings = container.read(notificationSettingsProvider.notifier);

    await settings.setMatches(false);
    expect(container.read(notificationSettingsProvider).matches, isFalse);

    respond =
        (request) => http.Response(
          jsonEncode({'notifications': body(request)}),
          200,
        );
    requests.clear();
    await settings.retryPendingChange();

    expect(requests.single.method, 'PATCH');
    expect(body(requests.single), {
      'matches': false,
      'messages': true,
      'reminders': true,
    });

    // Sent: nothing is pending anymore.
    requests.clear();
    await settings.retryPendingChange();
    expect(requests, isEmpty);
  });

  test('a vote response carries the card limit after that vote', () async {
    respond =
        (_) => http.Response(
          jsonEncode({
            'interaction': {
              'id': 'i1',
              'toUser': 'user-2',
              'type': 'crush',
              'createdAt': DateTime.now().toIso8601String(),
            },
            'matched': false,
            'match': null,
            'cardLimitStatus': {
              'limited': false,
              'viewsLeft': 7,
              'isPro': false,
              'maxCards': 10,
              'cooldownMinutes': 5,
            },
          }),
          201,
        );

    final response = await InteractionRemoteDataSource(
      api(),
    ).respondToInteraction(targetUserId: 'user-2', type: InteractionType.crush);

    expect(response.result.matched, isFalse);
    expect(response.cardLimitStatus?.viewsLeft, 7);
    expect(response.cardLimitStatus?.isPro, isFalse);
  });
}
