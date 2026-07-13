import 'api_service.dart';
import '../config/api_config.dart';

class PatientApiService {
  // Auth
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    return await ApiService.post('/patient/login', {
      'username': username,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiService.get('/patient/profile');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await ApiService.put('/patient/profile', profileData);
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await ApiService.put('/patient/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // Dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    return await ApiService.get('/patient/dashboard');
  }

  // Request Tests
  static Future<Map<String, dynamic>> requestTests({
    required List<String> tests,
  }) async {
    return await ApiService.post('/patient/request-tests', {'tests': tests});
  }

  // View Results
  static Future<Map<String, dynamic>> getMyResults() async {
    return await ApiService.get('/patient/results');
  }

  static Future<Map<String, dynamic>> getOrdersWithResults() async {
    return await ApiService.get('/patient/orders-with-results');
  }

  static Future<Map<String, dynamic>> getOrderResults(String orderId) async {
    return await ApiService.get('/patient/orders/$orderId/results');
  }

  static Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    return await ApiService.get('/patient/orders/$orderId');
  }

  static Future<Map<String, dynamic>> getMyOrders() async {
    return await ApiService.get('/patient/orders');
  }

  // Notifications
  static Future<Map<String, dynamic>> getNotifications() async {
    return await ApiService.get(ApiConfig.patientNotifications);
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    return await ApiService.put(
      '/patient/notifications/$notificationId/read',
      {},
    );
  }

  // Feedback
  static Future<Map<String, dynamic>> provideFeedback({
    required String targetType,
    String? targetId,
    required int rating,
    required String message,
    bool isAnonymous = false,
  }) async {
    return await ApiService.post('/patient/feedback', {
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

    return await ApiService.get('/patient/feedback?$queryString');
  }

  // Invoices/Billing
  static Future<Map<String, dynamic>> getMyInvoices({
    String? paymentStatus,
  }) async {
    final queryParams = <String, String>{};
    if (paymentStatus != null) {
      queryParams['payment_status'] = paymentStatus;
    }

    final queryString = queryParams.isNotEmpty
        ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    return await ApiService.get('/patient/invoices$queryString');
  }

  static Future<Map<String, dynamic>> getInvoiceById(String invoiceId) async {
    return await ApiService.get('/patient/invoices/$invoiceId');
  }
}
