import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/router.dart';
import '../services/api_service.dart';

// Conditionally import Firebase messaging only for mobile platforms
import 'notification_service_mobile.dart' as firebase_stub;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Callback for when notifications are received
  Function(String type, Map<String, dynamic> data)? _onNotificationReceived;

  // Store pending notification for navigation
  static const String _pendingNotificationKey = 'pending_notification_data';
  static const String _pendingNavigationKey = 'pending_navigation_target';

  // Store a pending navigation target (for when user clicks notification but needs to auth first)
  static Future<void> setPendingNavigation(String? route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (route != null) {
        await prefs.setString(_pendingNavigationKey, route);
        debugPrint('📱 Stored pending navigation: $route');
      } else {
        await prefs.remove(_pendingNavigationKey);
        debugPrint('📱 Cleared pending navigation');
      }
    } catch (e) {
      debugPrint('📱 Error storing pending navigation: $e');
    }
  }

  // Get and clear pending navigation target
  static Future<String?> getPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_pendingNavigationKey);
      if (route != null) {
        await prefs.remove(_pendingNavigationKey);
        debugPrint('📱 Retrieved and cleared pending navigation: $route');
      }
      return route;
    } catch (e) {
      debugPrint('📱 Error getting pending navigation: $e');
      return null;
    }
  }

  // Get pending notification data from SharedPreferences
  Future<Map<String, dynamic>?> _getPendingNotificationData() async {
    try {
      debugPrint('📱 _getPendingNotificationData called');
      final prefs = await SharedPreferences.getInstance();
      debugPrint('📱 SharedPreferences instance obtained');

      final dataString = prefs.getString(_pendingNotificationKey);
      debugPrint('📱 Raw dataString from SharedPreferences: $dataString');

      if (dataString != null) {
        debugPrint('📱 Parsing dataString...');
        final decoded = json.decode(dataString);
        debugPrint('📱 Decoded data: $decoded');

        final result = Map<String, dynamic>.from(decoded);
        debugPrint('📱 Final result: $result');
        return result;
      } else {
        debugPrint('📱 dataString is null');
        return null;
      }
    } catch (e) {
      debugPrint('📱 ERROR in _getPendingNotificationData: $e');
      return null;
    }
  }

  // Set pending notification data to SharedPreferences
  Future<void> _setPendingNotificationData(Map<String, dynamic>? data) async {
    try {
      debugPrint('📱 _setPendingNotificationData called with data: $data');
      final prefs = await SharedPreferences.getInstance();
      debugPrint('📱 SharedPreferences instance obtained for setting');

      if (data != null) {
        final encoded = json.encode(data);
        debugPrint('📱 Encoding data to JSON: $encoded');

        final success = await prefs.setString(_pendingNotificationKey, encoded);
        debugPrint('📱 SharedPreferences setString result: $success');
      } else {
        debugPrint('📱 Clearing pending notification data');
        final success = await prefs.remove(_pendingNotificationKey);
        debugPrint('📱 SharedPreferences remove result: $success');
      }
    } catch (e) {
      debugPrint('📱 ERROR in _setPendingNotificationData: $e');
    }
  }

  // Notification channels
  static const String _generalChannelId = 'general_notifications';
  static const String _resultsChannelId = 'test_results';
  static const String _ownerChannelId = 'owner_notifications';

  // Initialize Firebase and notifications (Mobile Only)
  Future<void> initialize() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // تهيئة Firebase messaging للموبايل فقط
      await firebase_stub.initializeFirebaseMessaging(this);
    } catch (e) {
      // Error initializing notifications
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels (Android)
    await _createNotificationChannels();
  }

  // Register callback for notification events
  void setNotificationCallback(
    Function(String type, Map<String, dynamic> data) callback,
  ) {
    _onNotificationReceived = callback;
  }

  // Remove callback
  void removeNotificationCallback() {
    _onNotificationReceived = null;
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
          _generalChannelId,
          'General Notifications',
          description: 'General app notifications',
          importance: Importance.defaultImportance,
          playSound: true,
        );

    const AndroidNotificationChannel resultsChannel =
        AndroidNotificationChannel(
          _resultsChannelId,
          'Test Results',
          description: 'Test result notifications',
          importance: Importance.max,
          playSound: true,
        );

    const AndroidNotificationChannel ownerChannel = AndroidNotificationChannel(
      _ownerChannelId,
      'Owner Notifications',
      description: 'Subscription and account notifications',
      importance: Importance.high,
      playSound: true,
    );

    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(generalChannel);

    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(resultsChannel);

    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(ownerChannel);
  }

  // Handle foreground messages
  Future<void> handleForegroundMessage(dynamic message) async {
    final notification = message.notification;
    final data = message.data;

    // Call callback if registered
    if (_onNotificationReceived != null && data != null) {
      final type = data['type'] ?? 'unknown';
      _onNotificationReceived!(type, data);
    }

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Medical Lab',
        body: notification.body ?? 'You have a new notification',
        payload: jsonEncode(data),
        channelId: _getChannelForMessage(data),
      );
    }
  }

  // Handle background messages (called when notification is tapped while app is in background)
  void handleBackgroundMessage(dynamic message) async {
    debugPrint(
      '📱 BACKGROUND MESSAGE OPENED (notification tapped): ${message.messageId}',
    );
    debugPrint('📱 Background message data: ${message.data}');

    final data = Map<String, dynamic>.from(message.data ?? {});

    // Call callback if registered
    if (_onNotificationReceived != null && data.isNotEmpty) {
      final type = data['type'] ?? 'unknown';
      _onNotificationReceived!(type, data);
    }

    // Navigate immediately since user tapped the notification and app is now in foreground
    debugPrint('📱 User tapped notification, navigating immediately');
    _navigateBasedOnMessage(data);
  }

  // Handle terminated messages (called when app was closed and notification is tapped)
  void handleTerminatedMessage(dynamic message) async {
    debugPrint(
      '📱 TERMINATED MESSAGE OPENED (app was closed): ${message.messageId}',
    );
    debugPrint('📱 Terminated message data: ${message.data}');

    final data = Map<String, dynamic>.from(message.data ?? {});

    // Store the notification data for navigation when app initializes
    await _setPendingNotificationData(data);

    // Call callback if registered
    if (_onNotificationReceived != null && data.isNotEmpty) {
      final type = data['type'] ?? 'unknown';
      _onNotificationReceived!(type, data);
    }

    // Also try to navigate after a delay (in case checkPendingNotifications misses it)
    debugPrint(
      '📱 Terminated notification stored, will navigate after app is ready',
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      debugPrint('📱 Delayed navigation attempt for terminated notification');
      _navigateBasedOnMessage(data);
    });
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateBasedOnMessage(data);
    }

    // Decrement badge when notification is tapped
    decrementBadge();
  }

  // Check for pending notifications and navigate if app is ready
  Future<void> checkPendingNotifications() async {
    debugPrint('📱 checkPendingNotifications called');

    final pendingData = await _getPendingNotificationData();
    debugPrint('📱 Retrieved pending notification data: $pendingData');

    if (pendingData != null) {
      debugPrint('📱 Found pending notification, attempting navigation');
      debugPrint('📱 Pending notification data: $pendingData');

      // Clear the stored data first
      await _setPendingNotificationData(null);

      // Use post-frame callback to ensure app is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📱 Post-frame navigation starting...');
        _navigateBasedOnMessage(pendingData);
      });
    } else {
      debugPrint('📱 No pending notification data found');
    }
  }

  // Navigate based on message data
  void _navigateBasedOnMessage(Map<String, dynamic> data) {
    final type = data['type'];
    final orderId = data['order_id'] ?? data['orderId'];
    final receiverModel = data['receiver_model'] ?? data['receiverModel'];

    debugPrint(
      '🔔 NAVIGATION CALLED - Type: $type, OrderID: $orderId, ReceiverModel: $receiverModel',
    );
    debugPrint('🔔 Full navigation data: $data');

    // For patient notifications, check if user is authenticated before navigating
    if (receiverModel == 'Patient') {
      debugPrint('🔔 Patient notification detected, checking authentication');
      _navigatePatientBasedOnMessage(type, orderId, data);
    } else {
      // For other user types, navigate directly
      debugPrint('🔔 Non-patient notification, navigating directly');
      _performNavigation(type, orderId, receiverModel, data);
    }
  }

  // Handle patient navigation with authentication check
  void _navigatePatientBasedOnMessage(
    String? type,
    String? orderId,
    Map<String, dynamic> data,
  ) {
    debugPrint(
      '🔔 _navigatePatientBasedOnMessage called with type: $type, orderId: $orderId',
    );
    // For patient notifications, always attempt navigation since the dashboard handles auth
    // If patient is not authenticated, the dashboard will redirect to login
    debugPrint(
      '📍 Patient notification: proceeding with navigation (dashboard handles auth)',
    );
    _performNavigation(type, orderId, 'Patient', data);
  }

  // Perform the actual navigation
  void _performNavigation(
    String? type,
    String? orderId,
    String? receiverModel,
    Map<String, dynamic> data,
  ) {
    debugPrint(
      '🎯 _performNavigation called with type: $type, orderId: $orderId, receiverModel: $receiverModel',
    );

    // Use a post-frame callback to ensure the app is ready for navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performNavigationInternal(type, orderId, receiverModel, data);
    });
  }

  void _performNavigationInternal(
    String? type,
    String? orderId,
    String? receiverModel,
    Map<String, dynamic> data,
  ) {
    debugPrint(
      '🎯 _performNavigationInternal: type=$type, orderId=$orderId, receiverModel=$receiverModel',
    );

    // Safety check - ensure router is available
    try {
      // Test if router is ready by checking current location
      final currentLocation =
          AppRouter.router.routerDelegate.currentConfiguration.fullPath;
      debugPrint('🎯 Current router location: $currentLocation');
    } catch (e) {
      debugPrint('🎯 Router not ready yet, scheduling retry...');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _performNavigationInternal(type, orderId, receiverModel, data);
      });
      return;
    }

    switch (type) {
      case 'test_result':
      case 'result_ready':
      case 'order_completed':
        // Patient: Navigate to order report
        if (receiverModel == 'Patient') {
          if (orderId != null && orderId.toString().isNotEmpty) {
            final targetRoute = '/patient-dashboard/order-report/$orderId';
            debugPrint('📍 Patient: Navigating to order report: $orderId');

            // Store pending navigation in case auth redirect happens
            setPendingNavigation(targetRoute);

            try {
              AppRouter.router.go(targetRoute);
              debugPrint('📍 Patient: Navigation to order report initiated');
            } catch (e) {
              debugPrint('📍 Patient: Navigation failed: $e, trying dashboard');
              try {
                AppRouter.router.go('/patient-dashboard');
              } catch (e2) {
                debugPrint('📍 Patient: Dashboard navigation also failed: $e2');
              }
            }
          } else {
            debugPrint('📍 Patient: No orderId, navigating to dashboard');
            try {
              AppRouter.router.go('/patient-dashboard');
              debugPrint('📍 Patient: Dashboard navigation successful');
            } catch (e) {
              debugPrint('📍 Patient: Dashboard navigation failed: $e');
            }
          }
        } else if (receiverModel == 'Doctor') {
          // Doctor: Navigate to patient report
          if (orderId != null && orderId.toString().isNotEmpty) {
            debugPrint('📍 Doctor: Navigating to patient report: $orderId');
            AppRouter.router.go('/doctor-dashboard/patient-report/$orderId');
          } else {
            debugPrint('📍 Doctor: No orderId, navigating to dashboard');
            AppRouter.router.go('/doctor-dashboard');
          }
        } else if (receiverModel == 'Staff') {
          // Staff: Navigate to dashboard (they can view order details in their dashboard)
          debugPrint('📍 Staff: Navigating to dashboard');
          AppRouter.router.go('/staff/dashboard');
        } else {
          // Unknown receiver model
          debugPrint(
            '📍 Unknown receiver model: $receiverModel, staying on current page',
          );
        }
        break;

      case 'result_uploaded':
        // Staff: Navigate to upload results section
        if (receiverModel == 'Staff') {
          debugPrint(
            '📍 Staff: Result uploaded, navigating to upload results section',
          );
          AppRouter.router.go(
            '/staff/dashboard/5',
          ); // Tab index 5 is upload results
        } else {
          debugPrint(
            '📍 Non-staff result_uploaded notification, staying on current page',
          );
        }
        break;

      case 'order_status_update':
        // Patient: Navigate to dashboard
        if (receiverModel == 'Patient') {
          AppRouter.router.go('/patient-dashboard');
        }
        break;

      case 'subscription':
      case 'renewal_request':
        // Admin: Navigate to Subscriptions tab (index 3) to handle renewal requests
        if (receiverModel == 'Admin') {
          debugPrint(
            '📍 Admin: Navigating to Subscriptions tab for renewal request',
          );
          AppRouter.router.go('/admin/dashboard/subscriptions');
        } else if (receiverModel == 'LabOwner' || receiverModel == 'Owner') {
          // Owner: Navigate to dashboard for subscription renewal
          debugPrint(
            '📍 Owner: Navigating to dashboard for subscription notification',
          );
          AppRouter.router.go('/owner/dashboard');
        }
        break;

      case 'inventory':
        // Owner: Navigate to inventory tab when staff reports issues
        if (receiverModel == 'LabOwner') {
          debugPrint(
            '📍 Owner: Navigating to inventory tab for inventory issue',
          );
          AppRouter.router.go('/owner/dashboard/inventory');
        }
        break;

      default:
        // For unknown types, navigate based on receiver model
        debugPrint('📍 Unknown notification type: $type');
        if (receiverModel == 'Patient') {
          AppRouter.router.go('/patient-dashboard');
        } else if (receiverModel == 'Admin') {
          AppRouter.router.go('/admin/dashboard');
        } else if (receiverModel == 'LabOwner') {
          AppRouter.router.go('/owner/dashboard');
        }
        // For Staff/Doctor, stay on current page
        break;
    }
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'general_notifications',
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          _getChannelName(channelId),
          channelDescription: _getChannelDescription(channelId),
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          visibility: NotificationVisibility.public, // Show on lock screen
          fullScreenIntent: true, // Enable heads-up notifications
          category: AndroidNotificationCategory.alarm,
        );

    // Get current badge count for iOS
    final prefs = await SharedPreferences.getInstance();
    final badgeCount = prefs.getInt('badge_count') ?? 0;

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: badgeCount + 1, // Increment badge for this notification
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      // Update badge count after showing notification
      await incrementBadge();
    } catch (e) {
      // Error showing local notification
    }
  }

  // Get appropriate channel for message
  String _getChannelForMessage(Map<String, dynamic> data) {
    final type = data['type'];
    final receiverModel = data['receiver_model'];
    switch (type) {
      case 'test_result':
        return _resultsChannelId;
      case 'subscription':
        if (receiverModel == 'LabOwner') {
          return _ownerChannelId;
        }
        return _generalChannelId;
      default:
        return _generalChannelId;
    }
  }

  // Get channel name for display
  String _getChannelName(String channelId) {
    switch (channelId) {
      case _resultsChannelId:
        return 'Test Results';
      case _ownerChannelId:
        return 'Owner Notifications';
      case _generalChannelId:
      default:
        return 'General Notifications';
    }
  }

  // Get channel description
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _resultsChannelId:
        return 'Test result notifications and updates';
      case _ownerChannelId:
        return 'Subscription and account notifications';
      case _generalChannelId:
      default:
        return 'General app notifications and updates';
    }
  }

  // Register FCM token (call after user login)
  // Register FCM token with backend (Mobile Only)
  Future<void> registerFCMToken({String? userId, String? userType}) async {
    try {
      // Import the mobile-specific function conditionally
      if (!kIsWeb) {
        // Wait a bit for FCM to initialize
        await Future.delayed(const Duration(seconds: 2));

        final token = await firebase_stub.getToken();
        if (token != null) {
          await saveTokenToServer(token, userId: userId, userType: userType);
        }
      }
    } catch (e) {
      // Error registering FCM token
    }
  }

  // Save FCM token to backend (Mobile Only)
  Future<void> saveTokenToServer(
    String token, {
    String? userId,
    String? userType,
  }) async {
    try {
      // Get userId from parameter or SharedPreferences
      final effectiveUserId =
          userId ??
          (await SharedPreferences.getInstance()).getString('patient_id');
      final effectiveUserType = userType ?? 'patient';

      if (effectiveUserId != null) {
        await ApiService.post('/notifications/register-token', {
          'userId': effectiveUserId,
          'token': token,
          'userType': effectiveUserType,
        });
      }
    } catch (e) {
      // Error saving FCM token
    }
  }

  // Public methods for sending notifications
  Future<void> showTestResultNotification(
    String patientName,
    String testName,
  ) async {
    await _showLocalNotification(
      title: 'Test Results Available',
      body: '$patientName\'s $testName results are ready',
      channelId: _resultsChannelId,
      payload: jsonEncode({
        'type': 'test_result',
        'patientName': patientName,
        'testName': testName,
      }),
    );
  }

  // Subscribe to topics (Mobile Only)
  Future<void> subscribeToTopic(String topic) async {
    await firebase_stub.subscribeToTopic(topic);
  }

  // Unsubscribe from topics (Mobile Only)
  Future<void> unsubscribeFromTopic(String topic) async {
    await firebase_stub.unsubscribeFromTopic(topic);
  }

  // Badge management methods
  Future<void> updateBadgeCount(int count) async {
    // For Android: badges are automatically managed by the notification system
    // For iOS: we can set badge numbers in notification details
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // Store badge count for iOS notifications
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('badge_count', count);
    }
  }

  Future<void> clearBadge() async {
    // For Android: clearing all notifications will clear the badge
    // For iOS: we can set badge to 0 in notification details
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('badge_count', 0);
    }
  }

  Future<void> incrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('badge_count') ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt('badge_count', newCount);
    // Badge will be shown automatically by Android notification system
  }

  Future<void> decrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('badge_count') ?? 0;
    final newCount = currentCount > 0 ? currentCount - 1 : 0;
    await prefs.setInt('badge_count', newCount);
    // Badge will be updated automatically by Android notification system
  }

  // Clear badge when viewing notifications
  Future<void> clearBadgeOnView() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('badge_count', 0);
    // For Android, clearing notifications will clear the badge
    // For iOS, we would need to show a notification with badge: 0
  }
}
