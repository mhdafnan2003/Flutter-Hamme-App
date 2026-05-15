import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../utils/app_exception.dart';
import 'secure_storage_service.dart';

class ApiService {
  ApiService({
    required http.Client client,
    required SecureStorageService storage,
  }) : _client = client,
       _storage = storage;

  final http.Client _client;
  final SecureStorageService _storage;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static bool _baseUrlLogged = false;
  Future<bool>? _refreshInFlight;

  Future<dynamic> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    debugPrint('[Api] GET start: $uri auth=$authenticated');
    final response = await _sendWithAuthRetry(
      (headers) => _client.get(uri, headers: headers),
      authenticated: authenticated,
    );
    debugPrint('[Api] GET done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path);
    final requestBody = body == null ? null : jsonEncode(body);
    debugPrint('[Api] POST start: $uri auth=$authenticated body=$requestBody');
    final response = await _sendWithAuthRetry(
      (headers) => _client.post(uri, headers: headers, body: requestBody),
      authenticated: authenticated,
    );
    debugPrint('[Api] POST done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
  }

  Future<dynamic> postMultipart(
    String path, {
    required List<http.MultipartFile> files,
    Map<String, String>? fields,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path);
    debugPrint('[Api] MULTIPART start: $uri auth=$authenticated');
    final response = await _sendMultipartWithAuthRetry(
      uri,
      files: files,
      fields: fields,
      authenticated: authenticated,
    );
    debugPrint('[Api] MULTIPART done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path);
    final requestBody = body == null ? null : jsonEncode(body);
    debugPrint('[Api] PATCH start: $uri auth=$authenticated body=$requestBody');
    final response = await _sendWithAuthRetry(
      (headers) => _client.patch(uri, headers: headers, body: requestBody),
      authenticated: authenticated,
    );
    debugPrint('[Api] PATCH done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
  }

  Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required bool authenticated,
  }) async {
    final headers = await _buildHeaders(authenticated: authenticated);
    final response = await send(headers).timeout(
      _requestTimeout,
      onTimeout:
          () =>
              throw const AppException(
                'Request timed out. Please check backend connectivity.',
                statusCode: 408,
              ),
    );

    if (authenticated && response.statusCode == 401) {
      debugPrint('[Api] 401 detected; attempting token refresh');
      final refreshed = await _tryRefreshTokens();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(authenticated: true);
        return send(retryHeaders).timeout(
          _requestTimeout,
          onTimeout:
              () =>
                  throw const AppException(
                    'Request timed out. Please check backend connectivity.',
                    statusCode: 408,
                  ),
        );
      }
    }

    return response;
  }

  Future<http.Response> _sendMultipartWithAuthRetry(
    Uri uri, {
    required List<http.MultipartFile> files,
    Map<String, String>? fields,
    required bool authenticated,
  }) async {
    Future<http.Response> sendWithHeaders(Map<String, String> headers) async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.addAll(files);

      final streamed = await _client
          .send(request)
          .timeout(
            _requestTimeout,
            onTimeout:
                () =>
                    throw const AppException(
                      'Request timed out. Please check backend connectivity.',
                      statusCode: 408,
                    ),
          );
      return http.Response.fromStream(streamed);
    }

    final headers = await _buildMultipartHeaders(authenticated: authenticated);
    final response = await sendWithHeaders(headers);

    if (authenticated && response.statusCode == 401) {
      debugPrint('[Api] 401 detected; attempting token refresh (multipart)');
      final refreshed = await _tryRefreshTokens();
      if (refreshed) {
        final retryHeaders = await _buildMultipartHeaders(authenticated: true);
        return sendWithHeaders(retryHeaders);
      }
    }

    return response;
  }

  Future<bool> _tryRefreshTokens() async {
    _refreshInFlight ??= _refreshTokens();
    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('[Api] refresh skipped: missing refresh token');
      return false;
    }

    final uri = _buildUri('/auth/refresh');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(
          _requestTimeout,
          onTimeout:
              () =>
                  throw const AppException(
                    'Request timed out. Please check backend connectivity.',
                    statusCode: 408,
                  ),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[Api] refresh failed: status=${response.statusCode}');
      await _storage.clearTokens();
      return false;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = decoded['accessToken'] as String?;
    final newRefreshToken = decoded['refreshToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('[Api] refresh failed: missing access token in response');
      await _storage.clearTokens();
      return false;
    }

    await _storage.storeTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
    );
    debugPrint('[Api] refresh success');
    return true;
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    if (!_baseUrlLogged) {
      _baseUrlLogged = true;
      debugPrint('[Api] Base URL = ${AppConstants.apiBaseUrl}');
    }
    return Uri.parse(
      '${AppConstants.apiBaseUrl}$path',
    ).replace(queryParameters: queryParameters);
  }

  Future<Map<String, String>> _buildHeaders({
    required bool authenticated,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (!authenticated) {
      return headers;
    }

    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const AppException('Authentication is required.', statusCode: 401);
    }

    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, String>> _buildMultipartHeaders({
    required bool authenticated,
  }) async {
    if (!authenticated) {
      return <String, String>{};
    }

    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const AppException('Authentication is required.', statusCode: 401);
    }

    return <String, String>{'Authorization': 'Bearer $token'};
  }

  dynamic _decodeResponse(http.Response response) {
    if (kDebugMode) {
      final body = response.body;
      final preview = body.length > 500 ? '${body.substring(0, 500)}...(truncated)' : body;
      debugPrint('[Api] raw response (${response.statusCode}): $preview');
    }
    final hasBody = response.body.trim().isNotEmpty;
    final decodedBody = hasBody ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    final message =
        decodedBody is Map<String, dynamic>
            ? decodedBody['message'] as String? ?? 'Unexpected request failure.'
            : 'Unexpected request failure.';

    throw AppException(message, statusCode: response.statusCode);
  }
}
