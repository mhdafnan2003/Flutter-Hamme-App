import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../routes/app_router.dart' show rootNavigatorKey;
import 'api_service.dart';

/// Registered as the FCM background handler in `main.dart`. Required to be a
/// top-level (or static) function annotated `@pragma('vm:entry-point')` per
/// the firebase_messaging plugin contract — it runs in a separate isolate.
///
/// The system tray already renders the notification for us (our pushes
/// always include a `notification` block), so there's nothing to display
/// here today; this only exists to satisfy that contract.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Requests permission, registers this device's FCM token with the backend,
/// and shows/handles notifications for votes and matches (see
/// `interactionService.js` on the backend for what triggers them).
class PushNotificationService {
  PushNotificationService(ApiService apiService)
    : _profileRemoteDataSource = ProfileRemoteDataSource(apiService);

  final ProfileRemoteDataSource _profileRemoteDataSource;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'hamme_default',
    'Hamme notifications',
    description: 'Votes and matches',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// Sets up local-notification display and message listeners. Safe to call
  /// once at app startup regardless of auth state.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        _navigateToTarget(payload);
      },
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => registerToken());
    debugPrint('[Push] Service initialized successfully');
  }

  /// Call once the router is mounted, to route into a notification that
  /// launched the app from a fully terminated state.
  Future<void> handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _handleMessageTap(message);
  }

  /// Registers (or refreshes) this device's push token. Call after every
  /// successful sign-in — a token is meaningless without an authenticated
  /// user to attach it to.
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _profileRemoteDataSource.registerDeviceToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('[Push] registerToken failed: $e');
    }
  }

  /// Call on logout, before local auth tokens are cleared, so a signed-out
  /// device stops receiving another account's notifications.
  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _profileRemoteDataSource.unregisterDeviceToken(token);
    } catch (e) {
      debugPrint('[Push] unregisterToken failed: $e');
    }
  }

  void _navigateToTarget(String? type) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    switch (type) {
      case 'match':
        GoRouter.of(context).go('/matches');
        break;
      case 'vote':
      default:
        GoRouter.of(context).go('/play');
        break;
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    _navigateToTarget(type);
  }

  /// FCM auto-displays notifications in the background. On iOS,
  /// `setForegroundNotificationPresentationOptions` handles foreground display natively.
  /// On Android foreground, we use local notifications to display the heads-up banner.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    debugPrint('[Push] onMessage received: ${notification?.title} - ${notification?.body}');
    if (notification == null) return;

    // iOS native APNs already renders the foreground alert via presentation options
    if (Platform.isIOS) return;

    final imageUrl =
        notification.android?.imageUrl ?? notification.apple?.imageUrl;
    final imagePath = imageUrl != null ? await _downloadImage(imageUrl) : null;
    final type = message.data['type'] as String? ?? 'vote';

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation:
              imagePath != null
                  ? BigPictureStyleInformation(
                    FilePathAndroidBitmap(imagePath),
                    largeIcon: FilePathAndroidBitmap(imagePath),
                  )
                  : null,
        ),
      ),
      payload: type,
    );
  }

  Future<String?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/push_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('[Push] image download failed: $e');
      return null;
    }
  }
}
