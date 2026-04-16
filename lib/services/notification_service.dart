import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      debugPrint('📲 NotificationService: Requesting FCM permissions...');
      // Ask user permission (required on iOS/macOS/web and Android 13+).
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('✅ FCM permission status: ${settings.authorizationStatus}');

        // setAutoInitEnabled is only supported on mobile platforms, not web
        if (!kIsWeb) {
          await _messaging.setAutoInitEnabled(true);
        }

      final hasWebVapidKey = AppConfig.firebaseWebVapidKey.isNotEmpty;
      final vapidKey = kIsWeb && hasWebVapidKey
          ? AppConfig.firebaseWebVapidKey
          : null;
      debugPrint('🔑 Using VAPID key: ${vapidKey != null ? "YES (${vapidKey.length} chars)" : "NO"}');

      if (kIsWeb && !hasWebVapidKey) {
        debugPrint('⚠️ Web VAPID key is empty. Add FIREBASE_WEB_VAPID_KEY in dart_defines.local.json.');
        return;
      }

      try {
        final token = await _messaging.getToken(vapidKey: vapidKey);
        debugPrint('🎫 FCM TOKEN: $token');
        debugPrint('📋 ⬆️ Copy this token to Firebase Console to send test notifications');
      } on MissingPluginException catch (e) {
        debugPrint('❌ FCM plugin not registered on this run: $e');
        debugPrint('ℹ️ Close all flutter run sessions, close Chrome, then run flutter clean; flutter pub get; flutter run -d chrome --dart-define-from-file=dart_defines.local.json');
      }
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.messageId}');
      debugPrint('FCM foreground title: ${message.notification?.title}');
      debugPrint('FCM foreground body: ${message.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification opened app: ${message.messageId}');
    });
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}
