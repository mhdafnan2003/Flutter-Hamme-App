import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/services/api_service.dart';
import 'package:hamme_app/core/services/secure_storage_service.dart';
import 'package:hamme_app/features/safety/data/datasources/safety_remote_data_source.dart';
import 'package:hamme_app/features/safety/domain/models/report_reason.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The safety endpoints must match the shared UGC-safety contract exactly.
void main() {
  late List<http.Request> requests;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.loadFromString(envString: 'API_BASE_URL=http://example.test/api/v1');
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token-1'});
    requests = [];
  });

  SafetyRemoteDataSource api(Object? response, {int status = 200}) {
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(response), status);
    });
    return SafetyRemoteDataSource(
      ApiService(
        client: client,
        storage: SecureStorageService(const FlutterSecureStorage()),
      ),
    );
  }

  Object? body(http.Request request) =>
      request.body.isEmpty ? null : jsonDecode(request.body);

  test('reports a vote with a reason, details and block', () async {
    final result = await api({
      'reportId': 'r1',
      'hidden': true,
      'blocked': true,
    }, status: 201).reportInteraction(
      'abc',
      reason: ReportReason.selfHarm,
      details: '  Please look at this  ',
    );

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/interactions/abc/report');
    expect(request.headers['authorization'], 'Bearer token-1');
    expect(body(request), {
      'reason': 'self_harm',
      'details': 'Please look at this',
      'block': true,
    });
    expect(result.reportId, 'r1');
    expect(result.hidden, true);
    expect(result.blocked, true);
  });

  test('caps report details at 500 characters', () async {
    await api({
      'reportId': 'r1',
      'blocked': false,
    }).reportUser('u1', details: 'x' * 700, block: false);

    final sent = body(requests.single)! as Map<String, dynamic>;
    expect(requests.single.url.path, '/api/v1/profiles/u1/report');
    expect((sent['details'] as String).length, 500);
    expect(sent['block'], false);
    expect(sent.containsKey('reason'), false);
  });

  test('hides a vote and blocks a profile', () async {
    await api({'hidden': true}).hideInteraction('abc');
    await api({'blocked': true}).blockUser('u1');

    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /api/v1/interactions/abc/hide',
      'POST /api/v1/profiles/u1/block',
    ]);
  });

  test("blocks a vote's sender without reporting it", () async {
    final blocked = await api({
      'blocked': true,
      'hidden': true,
    }).blockInteractionSender('abc');
    final nobody = await api({
      'blocked': false,
      'hidden': true,
    }).blockInteractionSender('old');

    expect(blocked, true);
    expect(nobody, false);
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /api/v1/interactions/abc/block',
      'POST /api/v1/interactions/old/block',
    ]);
  });

  test('lists and unblocks blocked users', () async {
    final blocked = await api({
      'users': [
        {
          'id': 'u1',
          'name': 'Sam',
          'username': 'sam',
          'avatarUrl': 'https://example.test/sam.jpg',
        },
      ],
      'anonymousBlockedCount': 2,
    }).getBlockedUsers();
    await api({'unblocked': true}).unblockUser('u1');
    final cleared = await api({'cleared': 2}).clearAnonymousBlocks();

    expect(blocked.users.single.displayName, 'Sam');
    expect(blocked.users.single.username, 'sam');
    expect(blocked.anonymousBlockedCount, 2);
    expect(cleared, 2);
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'GET /api/v1/profiles/me/blocked',
      'DELETE /api/v1/profiles/me/blocked/u1',
      'DELETE /api/v1/profiles/me/blocked-anonymous',
    ]);
  });
}
