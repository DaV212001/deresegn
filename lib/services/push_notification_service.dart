import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // If the message has a data payload or custom notification, we can present it via AwesomeNotifications
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'] ?? 'Deresegn Alert';
  final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

  if (title.isNotEmpty || body.isNotEmpty) {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'deresegn_fcm_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: message.data.map((k, v) => MapEntry(k, v.toString())),
      ),
    );
  }
}

class PushNotificationService {
  static final Logger _logger = Logger();
  static const String channelKey = 'deresegn_fcm_channel';
  static const String channelGroupKey = 'deresegn_alerts_group';

  /// Initializes AwesomeNotifications and Firebase Cloud Messaging
  static Future<void> initialize() async {
    try {
      // 1. Initialize Awesome Notifications
      await _initializeAwesomeNotifications();

      // 2. Initialize Firebase Core
      await Firebase.initializeApp();

      // 3. Register Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Request notification permissions from both FCM & Awesome Notifications
      await _requestPermissions();

      // 5. Fetch, log, and persist the FCM Token
      await _fetchAndPersistFcmToken();

      // 6. Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _logger.i('🔄 [FCM] Token refreshed: $newToken');
        await ConfigPreference.saveFcmToken(newToken);
      });

      // 7. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('📩 [FCM FOREGROUND MESSAGE] Title: ${message.notification?.title}, Body: ${message.notification?.body}, Data: ${message.data}');
        _showAwesomeNotification(message);
      });

      // 8. Handle user tapping notification when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.i('🔔 [FCM MESSAGE OPENED APP] ${message.data}');
      });

      _logger.i('✅ PushNotificationService initialized successfully.');
    } catch (e, stack) {
      _logger.e('❌ Failed to initialize PushNotificationService: $e', error: e, stackTrace: stack);
    }
  }

  static Future<void> _initializeAwesomeNotifications() async {
    await AwesomeNotifications().initialize(
      // Default icon: points to android/app/src/main/res/drawable/res_app_icon.png
      'resource://drawable/res_app_icon',
      [
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: channelKey,
          channelName: 'Deresegn Alerts',
          channelDescription: 'Notifications for POS transactions, fiscal compliance, and alerts',
          defaultColor: const Color(0xFF1565C0),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          criticalAlerts: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: channelGroupKey,
          channelGroupName: 'Deresegn Notifications',
        ),
      ],
      debug: kDebugMode,
    );

    // Register notification event listeners
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    _logger.i('👆 [AWESOME NOTIFICATION ACTION] Clicked notification with id: ${receivedAction.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    _logger.i('🔔 [AWESOME NOTIFICATION CREATED] id: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    _logger.i('📱 [AWESOME NOTIFICATION DISPLAYED] id: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    _logger.i('❌ [AWESOME NOTIFICATION DISMISSED] id: ${receivedAction.id}');
  }

  static Future<void> _requestPermissions() async {
    // Awesome Notifications permission
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // FCM permission (especially on iOS / web / Android 13+)
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _logger.i('🔔 FCM Permission status: ${settings.authorizationStatus}');
  }

  /// Fetches the device token, saves it in preferences, and prints prominent log banners
  static Future<String?> _fetchAndPersistFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ConfigPreference.saveFcmToken(token);
        _printTokenBanner(token);
        return token;
      } else {
        _logger.w('⚠️ FCM Token returned empty or null.');
      }
    } catch (e) {
      _logger.e('⚠️ Error fetching FCM device token: $e');
    }
    return null;
  }

  static String? _lastRegisteredFcmToken;
  static String? _lastRegisteredBranchId;
  static bool _isRegistering = false;

  /// Resets the registered token cache (e.g. on logout)
  static void resetRegistrationCache() {
    _lastRegisteredFcmToken = null;
    _lastRegisteredBranchId = null;
    _isRegistering = false;
  }

  /// Public method to get current token on demand (e.g. from UI)
  static Future<String?> getOrRefreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ConfigPreference.saveFcmToken(token);
        return token;
      }
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
    }
    return ConfigPreference.getFcmToken();
  }

  /// Registers the FCM device token with the backend using the branch bearer token.
  /// This is called exclusively after successful branch login.
  static Future<bool> registerDeviceToken({
    String? fcmToken,
    String? branchToken,
    bool force = false,
  }) async {
    if (_isRegistering) {
      _logger.d('⏳ [FCM] Device token registration already in progress. Skipping duplicate request.');
      return false;
    }

    try {
      _isRegistering = true;
      final token = fcmToken ??
          ConfigPreference.getFcmToken() ??
          await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        _logger.w('⚠️ [FCM] Cannot register device token: FCM token is null or empty.');
        return false;
      }

      final bToken = branchToken ?? ConfigPreference.getAccessToken();
      if (bToken == null || bToken.isEmpty) {
        _logger.i('ℹ️ [FCM] Branch bearer token is not available. Skipping registration.');
        return false;
      }

      final branchId = ConfigPreference.getBranchId() ?? '';

      // Prevent redundant registrations if token and branch have already been registered
      if (!force &&
          _lastRegisteredFcmToken == token &&
          _lastRegisteredBranchId == branchId &&
          branchId.isNotEmpty) {
        _logger.i('ℹ️ [FCM] Device token is already registered for branch $branchId. Skipping duplicate call.');
        return true;
      }

      bool success = false;
      await ApiService.registerFcmToken(
        fcmToken: token,
        branchToken: bToken,
        onSuccess: (response) {
          _lastRegisteredFcmToken = token;
          _lastRegisteredBranchId = branchId;
          _logger.i('✅ [FCM] Device token registered successfully with backend: ${response.statusCode}');
          success = true;
        },
        onFailure: (error, response) {
          _logger.e('❌ [FCM] Failed to register device token with backend: $error, status: ${response.statusCode}');
        },
      );
      return success;
    } catch (e, stack) {
      _logger.e('❌ [FCM] Exception while registering device token: $e', error: e, stackTrace: stack);
      return false;
    } finally {
      _isRegistering = false;
    }
  }

  static void _showAwesomeNotification(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Deresegn Notification';
    final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: message.data.map((k, v) => MapEntry(k, v.toString())),
      ),
    );
  }

  static void _printTokenBanner(String token) {
    _logger.i(
      '\n================================================================\n'
      '🔥 [FCM DEVICE TOKEN FOR BACKEND DEV]\n'
      'Device Token: $token\n'
      '================================================================',
    );
  }
}
