import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    : _apiService = apiService,
      _profileRemoteDataSource = ProfileRemoteDataSource(apiService);

  final ApiService _apiService;
  final ProfileRemoteDataSource _profileRemoteDataSource;

  // The last successful registration. Every launch (and, on iOS, every
  // onTokenRefresh, which fires at each start) asks to register, but the
  // backend only needs to hear about a new token or a different account.
  static const _registeredUserIdKey = 'push_registered_user_id';
  static const _registeredTokenKey = 'push_registered_token';
  static const _registeredAtKey = 'push_registered_at_ms';
  static const _registrationMaxAge = Duration(days: 7);
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
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => _registerToken(token: token),
    );
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
  /// user to attach it to. Skipped when the same account already registered
  /// the same token within the last 7 days.
  Future<void> registerToken() => _registerToken();

  /// Registers [token] (or the current one) for the signed-in account.
  Future<void> _registerToken({String? token}) async {
    try {
      final deviceToken = token ?? await FirebaseMessaging.instance.getToken();
      if (deviceToken == null) return;
      // The account the authenticated request is attributed to.
      final userId = await _apiService.sessionUserId();
      final preferences = await SharedPreferences.getInstance();
      if (userId != null &&
          _isRecentlyRegistered(preferences, userId, deviceToken)) {
        debugPrint('[Push] token already registered; skipped');
        return;
      }
      await _profileRemoteDataSource.registerDeviceToken(
        token: deviceToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      if (userId == null) return;
      await preferences.setString(_registeredUserIdKey, userId);
      await preferences.setString(_registeredTokenKey, deviceToken);
      await preferences.setInt(
        _registeredAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[Push] registerToken failed: $e');
    }
  }

  static bool _isRecentlyRegistered(
    SharedPreferences preferences,
    String userId,
    String token,
  ) {
    final registeredAt = preferences.getInt(_registeredAtKey);
    return registeredAt != null &&
        preferences.getString(_registeredUserIdKey) == userId &&
        preferences.getString(_registeredTokenKey) == token &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(registeredAt),
            ) <
            _registrationMaxAge;
  }

  /// Forgets the last registration so the next sign-in registers again. Call
  /// whenever the session ends: logout (via [unregisterToken]), account
  /// deletion and a ban.
  static Future<void> clearRegistrationCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_registeredUserIdKey);
      await preferences.remove(_registeredTokenKey);
      await preferences.remove(_registeredAtKey);
    } catch (e) {
      debugPrint('[Push] clearing the registration cache failed: $e');
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
    } finally {
      await clearRegistrationCache();
    }
  }

  // Locations of the main tab shell (Share / Play / Inbox).
  static const _tabLocations = {'/home', '/play', '/inbox'};

  void _navigateToTarget(String? type) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final router = GoRouter.of(context);
    if (type != 'match') {
      // Votes (and anything else) open Play, a tab of the shell; `go` to it
      // keeps the shell and its other tabs.
      router.go('/play');
      return;
    }
    final location =
        router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation;
    if (location == '/matches') return;
    if (_tabLocations.contains(location)) {
      // Open Matches over the tabs. `go` would dispose the tab shell, which
      // is then rebuilt, and its data refetched, on the way back.
      unawaited(router.push('/matches'));
    } else {
      // Splash, onboarding, the terms gate...: the router's redirects decide.
      router.go('/matches');
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
