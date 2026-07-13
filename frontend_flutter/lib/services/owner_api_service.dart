import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class OwnerApiService {
  // Ensure token is set before API calls
  static Future<void> ensureTokenInitialized() async {
    if (ApiService.authToken == null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('owner_token');
      if (token != null) {
        ApiService.setAuthToken(token);
      }
    }
  }

  // Auth
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    return await ApiService.post('/owner/login', {
      'username': username,
      'password': password,
    });
  }

  // Dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/dashboard');
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/profile');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put('/owner/profile', profileData);
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put('/owner/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // Staff Management
  static Future<Map<String, dynamic>> getStaff() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/staff');
  }

  static Future<Map<String, dynamic>> createStaff(
    Map<String, dynamic> staffData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/staff', staffData);
  }

  static Future<Map<String, dynamic>> updateStaff(
    String staffId,
    Map<String, dynamic> staffData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put('/owner/staff/$staffId', staffData);
  }

  static Future<Map<String, dynamic>> deleteStaff(String staffId) async {
    await ensureTokenInitialized();
    return await ApiService.delete('/owner/staff/$staffId');
  }

  // Doctor Management
  static Future<Map<String, dynamic>> getDoctors() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/doctors');
  }

  static Future<Map<String, dynamic>> createDoctor(
    Map<String, dynamic> doctorData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/doctors', doctorData);
  }

  static Future<Map<String, dynamic>> updateDoctor(
    String doctorId,
    Map<String, dynamic> doctorData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put('/owner/doctors/$doctorId', doctorData);
  }

  static Future<Map<String, dynamic>> deleteDoctor(String doctorId) async {
    await ensureTokenInitialized();
    return await ApiService.delete('/owner/doctors/$doctorId');
  }

  // Test Management
  static Future<Map<String, dynamic>> getTests() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/tests');
  }

  static Future<Map<String, dynamic>> createTest(
    Map<String, dynamic> testData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/tests', testData);
  }

  static Future<Map<String, dynamic>> updateTest(
    String testId,
    Map<String, dynamic> testData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put('/owner/tests/$testId', testData);
  }

  static Future<Map<String, dynamic>> deleteTest(String testId) async {
    await ensureTokenInitialized();
    return await ApiService.delete('/owner/tests/$testId');
  }

  // Test Component Management
  static Future<Map<String, dynamic>> getTestComponents(String testId) async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/tests/$testId/components');
  }

  static Future<Map<String, dynamic>> addTestComponent(
    String testId,
    Map<String, dynamic> componentData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.post(
      '/owner/tests/$testId/components',
      componentData,
    );
  }

  static Future<Map<String, dynamic>> updateTestComponent(
    String testId,
    String componentId,
    Map<String, dynamic> componentData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put(
      '/owner/tests/$testId/components/$componentId',
      componentData,
    );
  }

  static Future<Map<String, dynamic>> deleteTestComponent(
    String testId,
    String componentId,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.delete(
      '/owner/tests/$testId/components/$componentId',
    );
  }

  // Device Management
  static Future<Map<String, dynamic>> getDevices() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/devices');
  }

  static Future<Map<String, dynamic>> createDevice(
    Map<String, dynamic> deviceData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/devices', deviceData);
  }

  static Future<Map<String, dynamic>> updateDevice(
    String deviceId,
    Map<String, dynamic> deviceData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put('/owner/devices/$deviceId', deviceData);
  }

  static Future<Map<String, dynamic>> deleteDevice(String deviceId) async {
    await ensureTokenInitialized();
    return await ApiService.delete('/owner/devices/$deviceId');
  }

  // Inventory
  static Future<Map<String, dynamic>> getInventory() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/inventory');
  }

  static Future<Map<String, dynamic>> addStockInput(
    Map<String, dynamic> stockData,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/inventory/input', stockData);
  }

  // Reports
  static Future<Map<String, dynamic>> getReports({String? period}) async {
    final query = period != null ? '?period=$period' : '';
    await ensureTokenInitialized();
    return await ApiService.get('/owner/reports$query');
  }

  // Notifications (basic - deprecated, use the enhanced one below)
  // static Future<Map<String, dynamic>> getNotifications() async {
  //   await ensureTokenInitialized();
  //   return await ApiService.get(ApiConfig.ownerNotifications);
  // }

  // Feedback
  static Future<Map<String, dynamic>> provideFeedback({
    required String targetType,
    String? targetId,
    required int rating,
    required String message,
    bool isAnonymous = false,
  }) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/feedback', {
      'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      'rating': rating,
      'message': message,
      'is_anonymous': isAnonymous,
    });
  }

  static Future<Map<String, dynamic>> getMyFeedback({
    int page = 1,
    int limit = 10,
    String? targetType,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (targetType != null) {
      queryParams['target_type'] = targetType;
    }

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    await ensureTokenInitialized();
    return await ApiService.get('/owner/feedback?$queryString');
  }

  // Contact Admin
  static Future<Map<String, dynamic>> contactAdmin({
    required String title,
    required String message,
  }) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/contact-admin', {
      'title': title,
      'message': message,
    });
  }

  // Orders
  static Future<Map<String, dynamic>> getAllOrders({
    String? status,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (status != null) query += '&status=$status';
    if (startDate != null) query += '&startDate=$startDate';
    if (endDate != null) query += '&endDate=$endDate';

    await ensureTokenInitialized();
    return await ApiService.get('/owner/orders$query');
  }

  // Notifications & Messaging
  static Future<Map<String, dynamic>> getNotifications({
    bool unreadOnly = false,
  }) async {
    String query = unreadOnly ? '?unreadOnly=true' : '';
    await ensureTokenInitialized();
    return await ApiService.get('${ApiConfig.ownerNotifications}$query');
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.put(
      ApiConfig.ownerNotificationRead(notificationId),
      {},
    );
  }

  static Future<Map<String, dynamic>> sendNotificationToStaff({
    required String staffId,
    required String title,
    required String message,
    String? type,
  }) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/notifications/send', {
      'staff_id': staffId,
      'title': title,
      'message': message,
      if (type != null) 'type': type,
    });
  }

  static Future<Map<String, dynamic>> replyToNotification({
    required String notificationId,
    required String message,
  }) async {
    await ensureTokenInitialized();
    return await ApiService.post(
      ApiConfig.ownerNotificationReply(notificationId),
      {'message': message},
    );
  }

  static Future<Map<String, dynamic>> getConversationThread(
    String notificationId,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.get(
      ApiConfig.ownerNotificationConversation(notificationId),
    );
  }

  static Future<Map<String, dynamic>> getAllConversations() async {
    await ensureTokenInitialized();
    return await ApiService.get(ApiConfig.ownerConversations);
  }

  // Results & Invoices
  static Future<Map<String, dynamic>> getAllResults({
    int page = 1,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? status,
    String? patientName,
    String? testName,
  }) async {
    await ensureTokenInitialized();

    final queryParams = <String, String>{};
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (status != null) queryParams['status'] = status;
    if (patientName != null) queryParams['patientName'] = patientName;
    if (testName != null) queryParams['testName'] = testName;

    return await ApiService.get('/owner/results', params: queryParams);
  }

  static Future<Map<String, dynamic>> getAllInvoices({
    int page = 1,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? status,
    String? patientName,
  }) async {
    await ensureTokenInitialized();

    final queryParams = <String, String>{};
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (status != null) queryParams['status'] = status;
    if (patientName != null) queryParams['patientName'] = patientName;

    return await ApiService.get('/owner/invoices', params: queryParams);
  }

  static Future<Map<String, dynamic>> getInvoiceByOrderId(
    String orderId,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/invoices/order/$orderId');
  }

  static Future<Map<String, dynamic>> getInvoiceDetails(
    String invoiceId,
  ) async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/invoices/$invoiceId');
  }

  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/orders/$orderId');
  }

  // Audit Logs
  static Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? action,
    String? staffId,
  }) async {
    await ensureTokenInitialized();
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (action != null) queryParams['action'] = action;
    if (staffId != null) queryParams['staff_id'] = staffId;

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return await ApiService.get('/owner/audit-logs?$queryString');
  }

  static Future<Map<String, dynamic>> getAuditLogActions() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/audit-logs/actions');
  }

  // Subscription Renewal
  static Future<Map<String, dynamic>> requestRenewal({
    required int renewalPeriodMonths,
    String? message,
  }) async {
    await ensureTokenInitialized();
    return await ApiService.post('/owner/request-renewal', {
      'renewal_period_months': renewalPeriodMonths,
      'message': message ?? 'Requesting subscription renewal',
    });
  }

  // Get Renewal Requests
  static Future<Map<String, dynamic>> getRenewalRequests() async {
    await ensureTokenInitialized();
    return await ApiService.get('/owner/renewal-requests');
  }
}
