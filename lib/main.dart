import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await GetStorage.init();
  await _initializeFirebase();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: HammeApp()));
}

/// Push notifications need `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist` from a real Firebase project (see
/// PROJECT_SETUP.md). Until those are added, `Firebase.initializeApp()`
/// throws — guard it so the rest of the app still runs without push.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[Push] Firebase not configured, push notifications disabled: $e');
  }
}

