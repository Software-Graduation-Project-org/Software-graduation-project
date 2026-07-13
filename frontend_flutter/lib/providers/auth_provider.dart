import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  // Initialize auth state from local storage
  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('admin_token');
    final userJson = prefs.getString('user_data');
    if (userJson != null && userJson != '{}') {
      try {
        _user = Map<String, dynamic>.from(
          // Parse JSON string
          jsonDecode(userJson),
        );
      } catch (e) {
        _user = null;
      }
    }

    if (_token != null) {
      // Clear other auth tokens to ensure single user session
      await _clearOtherAuthTokens(prefs, 'admin');

      // Set token in API service if available and not already set
      if (ApiService.authToken == null) {
        ApiService.setAuthToken(_token);
      }

      // Register FCM token if user is already logged in
      if (_user != null && !kIsWeb) {
        try {
          final notificationService = NotificationService();
          await notificationService.registerFCMToken(
            userId: _user!['_id'],
            userType: 'admin',
          );
        } catch (e) {
          debugPrint('Failed to register FCM token on app start: $e');
        }
      }
    }

    notifyListeners();
  }

  // Admin login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/admin/login', {
        'username': username, // Backend expects 'username' not 'email'
        'password': password,
      });

      // Backend sends success message, not success boolean
      if (response['token'] != null) {
        _token = response['token'];
        _user = response['admin'];

        // Set token in API service for subsequent requests
        ApiService.setAuthToken(_token);

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user));

        // Register FCM token after successful login
        try {
          final notificationService = NotificationService();
          await notificationService
              .initialize(); // Initialize notification service
          await notificationService.registerFCMToken(
            userId: _user!['_id'],
            userType: 'admin',
          );
        } catch (e) {
          debugPrint('Failed to register FCM token after login: $e');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.setAuthToken(null);

    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_id');
    await prefs.remove('admin_email');
    await prefs.remove('user_data');

    notifyListeners();
  }

  Future<void> _clearOtherAuthTokens(
    SharedPreferences prefs,
    String currentRole,
  ) async {
    final tokensToRemove = {
      'admin': ['admin_token', 'admin_id', 'admin_email', 'user_data'],
      'owner': ['owner_token', 'owner_id', 'owner_email'],
      'staff': ['staff_token', 'staff_id', 'staff_email'],
      'doctor': ['doctor_token', 'doctor_id', 'doctor_email'],
      'patient': ['patient_token', 'patient_id', 'patient_email'],
    };

    for (final entry in tokensToRemove.entries) {
      if (entry.key != currentRole) {
        for (final key in entry.value) {
          await prefs.remove(key);
        }
      }
    }
  }

  // Get token for API requests
  String? getAuthToken() {
    return _token;
  }
}
