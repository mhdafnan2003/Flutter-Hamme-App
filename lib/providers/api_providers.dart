import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/api_service.dart';
import '../core/services/secure_storage_service.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
});

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    client: ref.watch(httpClientProvider),
    storage: ref.watch(secureStorageServiceProvider),
  );
});
