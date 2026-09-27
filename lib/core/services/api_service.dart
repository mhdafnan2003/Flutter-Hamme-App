import 'dart:async';
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
  final StreamController<AppException> _accountBannedController =
      StreamController<AppException>.broadcast();

  /// Fires when any response reports that the account (or this device) is
  /// banned (403 `ACCOUNT_BANNED`). The saved tokens are already cleared by
  /// then, so nothing keeps retrying with them; the auth layer listens to
  /// drop the local session and show the suspension notice.
  Stream<AppException> get accountBannedEvents =>
      _accountBannedController.stream;

  /// The id of the account the saved session belongs to (the access token's
  /// `sub` claim), or null when signed out or the token can't be read. The
  /// backend attributes authenticated requests to this account. Local only:
  /// no request is made and the token is not verified.
  Future<String?> sessionUserId() async {
    final parts = (await _storage.readAccessToken())?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final subject = payload is Map ? payload['sub'] : null;
      return subject is String && subject.isNotEmpty ? subject : null;
    } catch (_) {
      return null;
    }
  }

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
    // Purchase tokens, passwords and auth responses are bearer secrets. Do not
    // print request bodies even in debug builds.
    debugPrint(
      '[Api] POST start: $uri auth=$authenticated bodyBytes=${requestBody?.length ?? 0}',
    );
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

  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path);
    final requestBody = body == null ? null : jsonEncode(body);
    debugPrint('[Api] PUT start: $uri auth=$authenticated');
    final response = await _sendWithAuthRetry(
      (headers) => _client.put(uri, headers: headers, body: requestBody),
      authenticated: authenticated,
    );
    debugPrint('[Api] PUT done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path);
    final requestBody = body == null ? null : jsonEncode(body);
    debugPrint('[Api] DELETE start: $uri auth=$authenticated');
    final response = await _sendWithAuthRetry(
      (headers) => _client.delete(uri, headers: headers, body: requestBody),
      authenticated: authenticated,
    );
    debugPrint('[Api] DELETE done: $uri status=${response.statusCode}');
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

    if (authenticated &&
        response.statusCode == 401 &&
        await _renewAccessToken(sentWith: headers['Authorization'])) {
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

    return response;
  }

  /// After a 401 for a request sent with the [sentWith] Authorization header,
  /// makes a usable access token available. Returns whether to retry once.
  ///
  /// When another request already refreshed the tokens while this one was in
  /// flight, the saved token no longer matches the one sent: retry with it
  /// instead of rotating the refresh token again.
  Future<bool> _renewAccessToken({required String? sentWith}) async {
    final savedToken = await _storage.readAccessToken();
    if (savedToken != null &&
        savedToken.isNotEmpty &&
        'Bearer $savedToken' != sentWith) {
      debugPrint('[Api] 401 for an outdated token; retrying with the new one');
      return true;
    }
    debugPrint('[Api] 401 detected; attempting token refresh');
    return _tryRefreshTokens();
  }

  Future<http.Response> _sendMultipartWithAuthRetry(
    Uri uri, {
    required List<http.MultipartFile> files,
    Map<String, String>? fields,
    required bool authenticated,
  }) async {
    // A MultipartFile's stream can only be read once, so keep the bytes and
    // send fresh files on every attempt; the retry after a token refresh
    // would otherwise fail with "Can't finalize a finalized MultipartFile".
    final parts = [
      for (final file in files)
        (file: file, bytes: await file.finalize().toBytes()),
    ];

    Future<http.Response> sendWithHeaders(Map<String, String> headers) async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.addAll([
        for (final part in parts)
          http.MultipartFile.fromBytes(
            part.file.field,
            part.bytes,
            filename: part.file.filename,
            contentType: part.file.contentType,
          ),
      ]);

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

    if (authenticated &&
        response.statusCode == 401 &&
        await _renewAccessToken(sentWith: headers['Authorization'])) {
      final retryHeaders = await _buildMultipartHeaders(authenticated: true);
      return sendWithHeaders(retryHeaders);
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

    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      debugPrint('[Api] refresh failed: status=$status');
      final error = _errorFromBody(status, _decodeBody(response));
      if (error.isAccountBanned) {
        // Surface the ban itself rather than a generic expired session. The
        // tokens are cleared, so the original request is not retried.
        await _handleAccountBanned(error);
        throw error;
      }
      if (status == 400 || status == 401 || status == 403) {
        // The refresh token itself was rejected: the session is over.
        await _storage.clearTokens();
        return false;
      }
      // 5xx, 429 or a proxy error says nothing about the session. Keep the
      // tokens (a guest account can't sign back in) and fail this request; a
      // later request refreshes again.
      throw error;
    }

    final decoded = _decodeBody(response);
    final accessToken = decoded is Map ? decoded['accessToken'] : null;
    final newRefreshToken = decoded is Map ? decoded['refreshToken'] : null;
    if (accessToken is! String || accessToken.isEmpty) {
      debugPrint('[Api] refresh failed: missing access token in response');
      // A malformed answer (e.g. a proxy page) is not a rejected session.
      throw const AppException(
        'Could not refresh the session. Please try again.',
        statusCode: 502,
      );
    }

    await _storage.storeTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken is String ? newRefreshToken : null,
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

  Future<dynamic> _decodeResponse(http.Response response) async {
    if (kDebugMode) {
      debugPrint(
        '[Api] response status=${response.statusCode} bodyBytes=${response.body.length}',
      );
    }
    final decodedBody = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    final error = _errorFromBody(response.statusCode, decodedBody);
    if (error.isAccountBanned) {
      await _handleAccountBanned(error);
    }
    throw error;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      // Proxies and infrastructure rate limiters may return plain text or
      // HTML. Preserve it as an actionable API error instead of leaking a
      // JSON parsing exception into the UI.
      return response.body.trim();
    }
  }

  /// Builds the [AppException] for a failed response. Backend errors are
  /// `{ message, details }`; `details` is either a list of validation errors
  /// or an object carrying a machine-readable `code` (and sometimes `field`).
  AppException _errorFromBody(int statusCode, dynamic decodedBody) {
    String message = 'Unexpected request failure.';
    String? code;
    Object? details;
    if (decodedBody is Map<String, dynamic>) {
      message = decodedBody['message'] as String? ?? message;
      details = decodedBody['details'];
      if (details is Map) {
        code = details['code']?.toString();
      } else if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map<String, dynamic>) {
          final detailMsg = first['msg']?.toString();
          final detailField = first['path']?.toString();
          if (detailMsg != null && detailMsg.isNotEmpty) {
            message =
                detailField != null && detailField.isNotEmpty
                    ? '$detailField: $detailMsg'
                    : detailMsg;
          }
        }
      }
    } else if (decodedBody is String && decodedBody.isNotEmpty) {
      message = decodedBody;
    }

    return AppException(
      message,
      statusCode: statusCode,
      code: code,
      details: details,
    );
  }

  Future<void> _handleAccountBanned(AppException error) async {
    debugPrint('[Api] account banned: clearing saved session tokens');
    try {
      await _storage.clearTokens();
    } catch (clearError) {
      debugPrint('[Api] clearing tokens after ban failed: $clearError');
    }
    _accountBannedController.add(error);
  }
}
