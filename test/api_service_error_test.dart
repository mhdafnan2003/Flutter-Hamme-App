import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/services/api_service.dart';
import 'package:hamme_app/core/services/secure_storage_service.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory token storage (the real one needs the platform keychain).
class _MemoryTokenStorage extends SecureStorageService {
  _MemoryTokenStorage({this.accessToken, this.refreshToken})
    : super(const FlutterSecureStorage());

  String? accessToken;
  String? refreshToken;

  @override
  Future<void> storeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status);

const _bannedBody = {
  'message':
      'Your account has been suspended for violating the Hamme Terms of Use.',
  'details': {'code': 'ACCOUNT_BANNED'},
};

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://example.test/api/v1');
  });

  test('plain-text 429 response becomes an AppException', () async {
    final client = MockClient(
      (_) async => http.Response('Too many requests. Please try again.', 429),
    );
    final api = ApiService(
      client: client,
      storage: SecureStorageService(const FlutterSecureStorage()),
    );

    await expectLater(
      api.get('/interactions/received'),
      throwsA(
        isA<AppException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.message,
              'message',
              'Too many requests. Please try again.',
            ),
      ),
    );
  });

  test('validation errors still name the offending field', () async {
    final client = MockClient(
      (_) async => _json({
        'message': 'Validation failed.',
        'details': [
          {
            'msg': 'Display name must be 2 to 80 characters long.',
            'path': 'displayName',
          },
        ],
      }, 422),
    );
    final api = ApiService(client: client, storage: _MemoryTokenStorage());

    await expectLater(
      api.post('/auth/guest-register', body: const {}),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', isNull)
            .having(
              (error) => error.message,
              'message',
              'displayName: Display name must be 2 to 80 characters long.',
            ),
      ),
    );
  });

  test('objectionable content exposes its code, field and message', () async {
    final client = MockClient(
      (_) async => _json({
        'message':
            "That username isn't allowed on Hamme. Please choose another.",
        'details': {'code': 'OBJECTIONABLE_CONTENT', 'field': 'username'},
      }, 400),
    );
    final api = ApiService(client: client, storage: _MemoryTokenStorage());

    await expectLater(
      api.post('/auth/guest-register', body: const {}),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.isObjectionableContent,
              'objectionable',
              isTrue,
            )
            .having((error) => error.field, 'field', 'username')
            .having(
              (error) => error.message,
              'message',
              "That username isn't allowed on Hamme. Please choose another.",
            ),
      ),
    );
  });

  test('a banned account clears the saved session and is broadcast', () async {
    final client = MockClient((_) async => _json(_bannedBody, 403));
    final storage = _MemoryTokenStorage(
      accessToken: 'access',
      refreshToken: 'refresh',
    );
    final api = ApiService(client: client, storage: storage);
    final bans = <AppException>[];
    final subscription = api.accountBannedEvents.listen(bans.add);
    addTearDown(subscription.cancel);

    await expectLater(
      api.get('/interactions/received', authenticated: true),
      throwsA(
        isA<AppException>()
            .having((error) => error.isAccountBanned, 'banned', isTrue)
            .having((error) => error.statusCode, 'statusCode', 403),
      ),
    );
    await pumpEventQueue();

    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
    expect(bans, hasLength(1));
  });

  test('a ban reported by the token refresh ends the retry loop', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path.endsWith('/auth/refresh')) {
        return _json(_bannedBody, 403);
      }
      return _json({'message': 'Token expired.'}, 401);
    });
    final storage = _MemoryTokenStorage(
      accessToken: 'expired',
      refreshToken: 'refresh',
    );
    final api = ApiService(client: client, storage: storage);
    final bans = <AppException>[];
    final subscription = api.accountBannedEvents.listen(bans.add);
    addTearDown(subscription.cancel);

    await expectLater(
      api.get('/profiles/me', authenticated: true),
      throwsA(
        isA<AppException>().having(
          (error) => error.isAccountBanned,
          'banned',
          isTrue,
        ),
      ),
    );
    await pumpEventQueue();

    // One original request and one refresh: the request is not retried.
    expect(requests, ['/api/v1/profiles/me', '/api/v1/auth/refresh']);
    expect(storage.accessToken, isNull);
    expect(bans, hasLength(1));
  });
}
