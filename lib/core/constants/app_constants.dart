import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

final class AppConstants {
  static String get apiBaseUrl {
    final explicit = dotenv.env['API_BASE_URL'];
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final emulator = dotenv.env['API_BASE_URL_EMULATOR'];
    final device = dotenv.env['API_BASE_URL_DEVICE'];
    final web = dotenv.env['API_BASE_URL_WEB'];
    final prod = dotenv.env['API_BASE_URL_PROD'];

    if (kReleaseMode && prod != null && prod.isNotEmpty) return prod;
    if (kIsWeb && web != null && web.isNotEmpty) return web;
    if (!kIsWeb && Platform.isAndroid) {
      // Real devices should use LAN IP; emulator URL is only fallback.
      if (device != null && device.isNotEmpty) return device;
      if (emulator != null && emulator.isNotEmpty) return emulator;
    }
    if (device != null && device.isNotEmpty) return device;
    return 'http://127.0.0.1:3000/api/v1';
  }

  static String get shareLinkBase =>
      dotenv.env['SHARE_LINK_BASE'] ?? 'https://app.hamme.link/u';

  static String get appScheme => dotenv.env['APP_SCHEME'] ?? 'hamme';

  static String get appHost => dotenv.env['APP_HOST'] ?? 'app.hamme.link';

  static String buildUserShareLink(String? shareCode) {
    final cleaned = (shareCode ?? '').trim().replaceAll('@', '');
    if (cleaned.isEmpty) {
      return shareLinkBase;
    }
    final base = shareLinkBase.endsWith('/')
        ? shareLinkBase.substring(0, shareLinkBase.length - 1)
        : shareLinkBase;
    return '$base/$cleaned';
  }
}
