import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/services/api_service.dart';
import 'package:hamme_app/core/services/secure_storage_service.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}
