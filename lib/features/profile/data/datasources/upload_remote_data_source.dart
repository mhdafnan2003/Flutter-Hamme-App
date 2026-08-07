import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/services/api_service.dart';

class UploadRemoteDataSource {
  UploadRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<String> uploadProfileImageBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    debugPrint(
      '[UploadDS] uploadProfileImageBytes start name=$filename bytes=${bytes.length}',
    );
    final file = http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename.isNotEmpty ? filename : 'profile.jpg',
      // MultipartFile defaults to application/octet-stream. The API correctly
      // rejects that generic type, so preserve the selected image's MIME type.
      contentType: _imageMediaType(filename),
    );
    return _upload(file);
  }

  MediaType _imageMediaType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      // The callers use profile.jpg when the picker does not provide a name.
      _ => MediaType('image', 'jpeg'),
    };
  }

  Future<String> uploadProfileImage({required File file}) async {
    final filename = file.path.split('/').last;
    debugPrint('[UploadDS] uploadProfileImageFile start name=$filename');
    final multipart = await http.MultipartFile.fromPath(
      'image',
      file.path,
      filename: filename.isNotEmpty ? filename : 'profile.jpg',
    );
    return _upload(multipart);
  }

  Future<String> _upload(http.MultipartFile file) async {
    final response =
        await _apiService.postMultipart(
              '/upload/profile-image',
              files: [file],
              authenticated: true,
            )
            as Map<String, dynamic>;

    final imageUrl = response['imageUrl'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Upload did not return an image URL.');
    }
    debugPrint('[UploadDS] upload success url=$imageUrl');
    return imageUrl;
  }
}
