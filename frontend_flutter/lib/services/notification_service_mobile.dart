// Mobile implementation for Firebase messaging
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 BACKGROUND MESSAGE RECEIVED: ${message.messageId}');
  debugPrint('📱 Background message data: ${message.data}');

  try {
    // Store the notification data directly in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final encodedData = json.encode(message.data);
    debugPrint('📱 Storing notification data: $encodedData');

    final success = await prefs.setString(
      'pending_notification_data',
      encodedData,
    );
    debugPrint('📱 SharedPreferences setString result: $success');

    // Verify it was stored
    final stored = prefs.getString('pending_notification_data');
    debugPrint('📱 Verification - stored data: $stored');

    debugPrint(
      '📱 Notification stored in SharedPreferences for navigation when app becomes active',
    );
  } catch (e) {
    debugPrint('📱 ERROR storing notification in background: $e');
  }
}

// Initialize background message handler (called before Firebase initialization)
Future<void> initializeFirebaseMessagingBackground() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

Future<void> initializeFirebaseMessaging(dynamic service) async {
  final messaging = FirebaseMessaging.instance;

  // Register background message handler BEFORE requesting permissions
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request permissions
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint('Permission granted: ${settings.authorizationStatus}');

  // Get FCM token
  String? token = await messaging.getToken();
  if (token != null) {
    debugPrint('FCM Token: $token');
    await service.saveTokenToServer(token);
  }

  // Handle token refresh
  messaging.onTokenRefresh.listen((newToken) async {
    debugPrint('Token refreshed: $newToken');
    await service.saveTokenToServer(newToken);
  });

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen(service.handleForegroundMessage);

  // Handle background messages (when app is in background but not terminated)
  FirebaseMessaging.onMessageOpenedApp.listen(service.handleBackgroundMessage);

  // Handle initial message when app is launched from terminated state
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    service.handleTerminatedMessage(initialMessage);
  }
}

Future<String?> getToken() async {
  return await FirebaseMessaging.instance.getToken();
}

Future<void> subscribeToTopic(String topic) async {
  await FirebaseMessaging.instance.subscribeToTopic(topic);
}

Future<void> unsubscribeFromTopic(String topic) async {
  await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}
