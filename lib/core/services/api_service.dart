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

  Future<dynamic> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = await _buildHeaders(authenticated: authenticated);
    debugPrint('[Api] GET start: $uri auth=$authenticated');
    final response =
        await _client
            .get(uri, headers: headers)
            .timeout(
              _requestTimeout,
              onTimeout: () => throw const AppException(
                'Request timed out. Please check backend connectivity.',
                statusCode: 408,
              ),
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
    final headers = await _buildHeaders(authenticated: authenticated);
    final requestBody = body == null ? null : jsonEncode(body);
    debugPrint('[Api] POST start: $uri auth=$authenticated body=$requestBody');
    final response =
        await _client
            .post(
              uri,
              headers: headers,
              body: requestBody,
            )
            .timeout(
              _requestTimeout,
              onTimeout: () => throw const AppException(
                'Request timed out. Please check backend connectivity.',
                statusCode: 408,
              ),
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
    final headers = await _buildMultipartHeaders(authenticated: authenticated);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.addAll(files);

    debugPrint('[Api] MULTIPART start: $uri auth=$authenticated');
    final streamed = await _client
        .send(request)
        .timeout(
          _requestTimeout,
          onTimeout: () => throw const AppException(
            'Request timed out. Please check backend connectivity.',
            statusCode: 408,
          ),
        );
    final response = await http.Response.fromStream(streamed);
    debugPrint('[Api] MULTIPART done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(authenticated: authenticated);
    final requestBody = body == null ? null : jsonEncode(body);
    debugPrint('[Api] PATCH start: $uri auth=$authenticated body=$requestBody');
    final response =
        await _client
            .patch(
              uri,
              headers: headers,
              body: requestBody,
            )
            .timeout(
              _requestTimeout,
              onTimeout: () => throw const AppException(
                'Request timed out. Please check backend connectivity.',
                statusCode: 408,
              ),
            );
    debugPrint('[Api] PATCH done: $uri status=${response.statusCode}');
    return _decodeResponse(response);
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
    debugPrint('[Api] raw response (${response.statusCode}): ${response.body}');
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
