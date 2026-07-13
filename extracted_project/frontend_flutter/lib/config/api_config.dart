import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Base URL - Update this to your backend URL
  // For mobile testing, use your computer's IP address instead of localhost
  //static const String baseUrl = 'http://192.168.1.6:5000/api';

  static String get baseUrl {
    if (kIsWeb) {
      // For web development
      return 'http://127.0.0.1:3000/api';
    } else if (Platform.isAndroid) {
      // For Android physical devices, use your computer's IP address
      // For emulator use 10.0.2.2, for physical device use actual IP
      return 'http://192.168.1.6:3000/api';
    } else if (Platform.isIOS) {
      // For iOS devices/simulator, use the host machine's IP
      return 'http://192.168.1.6:3000/api';
    } else {
      // Fallback for other platforms
      return 'http://127.0.0.1:3000/api';
    }
  }

  // Admin Authentication
  static const String adminLogin = '/admin/login';

  // Admin Dashboard & Stats
  static const String adminDashboard = '/admin/dashboard';
  static const String adminStats = '/admin/stats';
  static const String adminSystemHealth = '/admin/system-health';
  static const String adminRealtimeMetrics = '/admin/realtime-metrics';
  static const String adminAlerts = '/admin/alerts';
  static const String adminExpiringSubscriptions =
      '/admin/expiring-subscriptions';

  // Lab Owner Management
  static const String adminLabOwners = '/admin/labowners';
  static const String adminPendingLabOwners = '/admin/labowners/pending';

  // Lab Owner Actions (use with ownerId parameter)
  static String adminApproveLabOwner(String ownerId) =>
      '/admin/labowner/$ownerId/approve';
  static String adminRejectLabOwner(String ownerId) =>
      '/admin/labowner/$ownerId/reject';
  // GET /admin/labowners/:ownerId
  // PUT /admin/labowner/:ownerId/approve
  // PUT /admin/labowner/:ownerId/reject
  // PUT /admin/labowners/:ownerId/deactivate
  // PUT /admin/labowners/:ownerId/reactivate

  // Notifications
  static const String adminNotifications = '/admin/notifications';
  static const String adminSendNotification = '/admin/notifications/send';
  static String adminMarkNotificationRead(String notificationId) =>
      '/admin/notifications/$notificationId/read';

  // Feedback
  static const String adminFeedback = '/admin/feedback';

  // Renewal Requests
  static const String adminRenewalRequests = '/admin/renewal-requests';
  static String adminApproveRenewalRequest(String requestId) =>
      '/admin/renewal-requests/$requestId/approve';
  static String adminDenyRenewalRequest(String requestId) =>
      '/admin/renewal-requests/$requestId/deny';

  // Owner Notifications
  static const String ownerNotifications = '/owner/notifications';
  static const String ownerConversations = '/owner/conversations';

  // Owner Notification Actions
  static String ownerNotificationReply(String notificationId) =>
      '/owner/notifications/$notificationId/reply';
  static String ownerNotificationConversation(String notificationId) =>
      '/owner/notifications/$notificationId/conversation';
  static String ownerNotificationRead(String notificationId) =>
      '/owner/notifications/$notificationId/read';

  // Owner Inventory Management
  static const String ownerInventory = '/owner/inventory';
  static const String ownerInventoryInput = '/owner/inventory/input';

  // Owner Orders Management
  static const String ownerOrders = '/owner/orders';

  // Owner Reports & Analytics
  static const String ownerReports = '/owner/reports';

  // Owner Audit Logs
  static const String ownerAuditLogs = '/owner/audit-logs';

  // Doctor Notifications
  static const String doctorNotifications = '/doctor/notifications';

  // Patient Notifications
  static const String patientNotifications = '/patient/notifications';

  // Staff Notifications (use with staffId parameter)
  // GET /staff/notifications/:staffId

  // Staff Orders
  static const String staffOrders = '/staff/orders';
  static const String staffPendingOrders = '/staff/pending-orders';

  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Build full URL
  static String buildUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
