import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  // Save token to SharedPreferences and set for API requests
  static Future<void> saveAndSetToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_token', token);
    setAuthToken(token);
  }

  static String? _authToken;

  // Public getter for auth token
  static String? get authToken => _authToken;

  // Set auth token
  static void setAuthToken(String? token) {
    _authToken = token;
  }

  // Get headers with auth token
  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  // POST request
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    // print('🔍 HTTP DEBUG: POST $url');
    // print('🔍 HTTP DEBUG: Headers: ${_getHeaders()}');
    // print('🔍 HTTP DEBUG: Body: $body');

    final response = await http
        .post(url, headers: _getHeaders(), body: jsonEncode(body))
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timeout - please check your connection');
          },
        );

    // print('🔍 HTTP DEBUG: Response status: ${response.statusCode}');
    // print('🔍 HTTP DEBUG: Response body: ${response.body}');

    return _handleResponse(response);
  }

  // POST request with extended timeout for long-running operations (e.g., HL7 simulation)
  static Future<Map<String, dynamic>> postWithLongTimeout(
    String endpoint,
    Map<String, dynamic> body, {
    int timeoutSeconds = 90,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http
        .post(url, headers: _getHeaders(), body: jsonEncode(body))
        .timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            throw Exception(
              'Operation timed out after $timeoutSeconds seconds',
            );
          },
        );

    return _handleResponse(response);
  }

  // GET request
  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final response = await http
        .get(uri, headers: _getHeaders())
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timeout - please check your connection');
          },
        );

    return _handleResponse(response);
  }

  // PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final response = await http.put(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final response = await http.delete(url, headers: _getHeaders());

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Admin lab owner management
  static Future<Map<String, dynamic>> approveLabOwner(
    String ownerId, {
    String? subscriptionEnd,
    double? subscriptionFee,
  }) async {
    final endpoint = ApiConfig.adminApproveLabOwner(ownerId);

    // Calculate subscription end date (1 month from now) if not provided
    final endDate =
        subscriptionEnd ??
        DateTime.now().add(const Duration(days: 30)).toIso8601String();

    return await put(endpoint, {
      'subscription_end': endDate,
      if (subscriptionFee != null) 'subscriptionFee': subscriptionFee,
    });
  }

  static Future<Map<String, dynamic>> rejectLabOwner(
    String ownerId, {
    String? rejectionReason,
  }) async {
    final endpoint = ApiConfig.adminRejectLabOwner(ownerId);
    return await put(
      endpoint,
      rejectionReason != null ? {'rejection_reason': rejectionReason} : {},
    );
  }

  // Admin notifications
  static Future<Map<String, dynamic>> sendNotificationToOwner({
    required String ownerId,
    required String title,
    required String message,
    String type = 'message',
  }) async {
    final result = await post(ApiConfig.adminSendNotification, {
      'receiver_model': 'Owner',
      'type': type,
      'title': title,
      'message': message,
      'receiver_id': ownerId,
    });

    return result;
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    final endpoint = ApiConfig.adminMarkNotificationRead(notificationId);
    return await put(endpoint, {});
  }

  // Save FCM token to server
  static Future<Map<String, dynamic>> saveFCMToken(
    String userId,
    String token,
    String platform,
  ) async {
    final endpoint = '/notifications/register-token';
    return await post(endpoint, {
      'user_id': userId,
      'token': token,
      'platform': platform,
    });
  }

  // Handle response
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      // If response is an array, return it directly
      // If it's an object, return it as is
      return decoded;
    } else {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final message = body['message'] ?? body['error'] ?? 'Request failed';
        return {
          'success': false,
          'message': message is String ? message : message.toString(),
        };
      }
      return {'success': false, 'message': 'Request failed'};
    }
  }
}
