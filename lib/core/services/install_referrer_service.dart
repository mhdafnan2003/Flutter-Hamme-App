import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

class InstallReferrerPayload {
  const InstallReferrerPayload({
    this.token,
    this.shareCode,
    this.type,
  });

  final String? token;
  final String? shareCode;
  final String? type;

  bool get hasUsefulData =>
      (token != null && token!.isNotEmpty) ||
      (shareCode != null && shareCode!.isNotEmpty);
}

class InstallReferrerService {
  Future<InstallReferrerPayload?> readPayload() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final referrerDetails = await PlayInstallReferrer.installReferrer;
      final raw = referrerDetails?.installReferrer ?? '';
      if (raw.isEmpty) return null;

      final params = Uri.splitQueryString(raw);
      return InstallReferrerPayload(
        token: params['hamme_token'],
        shareCode: params['hamme_code'],
        type: params['hamme_type'],
      );
    } catch (e) {
      debugPrint('[InstallReferrer] Failed to read: $e');
      return null;
    }
  }
}
