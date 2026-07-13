import 'api_service.dart';
import '../config/api_config.dart';

class DoctorApiService {
  // Auth
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    return await ApiService.post('/doctor/login', {
      'username': username,
      'password': password,
    });
  }

  // Dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    return await ApiService.get('/doctor/dashboard');
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiService.get('/doctor/profile');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await ApiService.put('/doctor/profile', profileData);
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await ApiService.put('/doctor/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // Patients
  static Future<Map<String, dynamic>> getMyPatients() async {
    return await ApiService.get('/doctor/patients');
  }

  static Future<Map<String, dynamic>> getPatientDetails(
    String patientId,
  ) async {
    return await ApiService.get('/doctor/patient/$patientId');
  }

  static Future<Map<String, dynamic>> getPatientTestHistory(
    String patientId,
  ) async {
    return await ApiService.get('/doctor/patient/$patientId/history');
  }

  static Future<Map<String, dynamic>> searchPatients(String query) async {
    return await ApiService.get('/doctor/patients/search?q=$query');
  }

  // Request Tests
  static Future<Map<String, dynamic>> requestTest({
    required String patientId,
    required List<String> tests,
  }) async {
    return await ApiService.post('/doctor/request-test', {
      'patient_id': patientId,
      'tests': tests,
    });
  }

  // View Results
  static Future<Map<String, dynamic>> getPatientResults(
    String patientId,
  ) async {
    return await ApiService.get('/doctor/patient/$patientId/history');
  }

  // Notifications
  static Future<Map<String, dynamic>> getNotifications() async {
    return await ApiService.get(ApiConfig.doctorNotifications);
  }

  // Feedback
  static Future<Map<String, dynamic>> provideFeedback({
    required String targetType,
    String? targetId,
    required int rating,
    required String message,
    bool isAnonymous = false,
  }) async {
    return await ApiService.post('/doctor/feedback', {
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

    return await ApiService.get('/doctor/feedback?$queryString');
  }

  // Patient Orders and Reports
  static Future<Map<String, dynamic>> getPatientOrdersWithResults({
    String? search,
  }) async {
    final queryString = search != null && search.isNotEmpty
        ? '?search=$search'
        : '';
    return await ApiService.get('/doctor/patient-orders$queryString');
  }

  static Future<Map<String, dynamic>> getOrderResults(String orderId) async {
    return await ApiService.get('/doctor/order/$orderId/results');
  }
}
