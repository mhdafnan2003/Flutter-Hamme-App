import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interaction_providers.dart';

/// Refreshes the Play data when a vote or match push arrives while the app is
/// open. The backend pushes every change the Play screen shows (new votes,
/// matches, and anonymous votes once their reveal window ends), so the app
/// no longer needs to poll for them. Kept alive by the main tab shell.
final pushDataRefreshProvider = Provider<void>((ref) {
  // Push is disabled when Firebase isn't configured (see main.dart).
  if (Firebase.apps.isEmpty) return;

  Timer? debounce;
  var refreshMatches = false;
  StreamSubscription<RemoteMessage>? subscription;
  try {
    subscription = FirebaseMessaging.onMessage.listen((message) {
      final type = message.data['type'];
      if (type != 'vote' && type != 'match') return;
      if (type == 'match') refreshMatches = true;
      // A reciprocal vote sends a 'vote' and a 'match' push together; refresh
      // once for both.
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 1), () {
        ref.invalidate(receivedInteractionsProvider);
        if (refreshMatches) ref.invalidate(matchesProvider);
        refreshMatches = false;
      });
    });
  } catch (error) {
    debugPrint('[Push] data refresh disabled: $error');
  }

  ref.onDispose(() {
    debounce?.cancel();
    subscription?.cancel();
  });
});
