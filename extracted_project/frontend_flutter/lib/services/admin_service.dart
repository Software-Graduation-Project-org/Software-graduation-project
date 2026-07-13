import 'api_service.dart';

class AdminService {
  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiService.get('/admin/profile');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await ApiService.put('/admin/profile', profileData);
  }

  // Get admin contact information for landing page
  static Future<Map<String, dynamic>> getContactInfo() async {
    try {
      final response = await ApiService.get('/admin/contact-info');
      return {'success': true, 'contact': response['contact'] ?? {}};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Reply to owner notification (with WhatsApp)
  static Future<Map<String, dynamic>> replyToOwnerNotification(
    String notificationId,
    String message,
  ) async {
    try {
      final response = await ApiService.post(
        '/admin/notifications/$notificationId/reply',
        {'message': message},
      );
      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send reply: ${e.toString()}',
      };
    }
  }
}
