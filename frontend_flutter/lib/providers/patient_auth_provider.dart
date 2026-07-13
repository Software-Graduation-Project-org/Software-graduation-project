import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/patient_api_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';

class PatientAuthProvider extends ChangeNotifier {
  String? _token;
  User? _user;
  bool _isLoading = false;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get patientId => _user?.id;

  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('patient_token');

    if (_token != null) {
      // Clear other auth tokens to ensure single user session
      await _clearOtherAuthTokens(prefs, 'patient');

      // Only set global token if not already set
      if (ApiService.authToken == null) {
        ApiService.setAuthToken(_token);
      }

      // Try to load full user data from profile endpoint
      try {
        final profileResponse = await PatientApiService.getProfile();
        _user = User.fromJson(profileResponse);
      } catch (e) {
        // If profile fails, fallback to basic user data
        final userId = prefs.getString('patient_id');
        final userEmail = prefs.getString('patient_email');
        if (userId != null && userEmail != null) {
          _user = User(id: userId, email: userEmail, role: 'Patient');
        }
      }

      // Register FCM token if user is already logged in
      if (_user != null && !kIsWeb) {
        try {
          final notificationService = NotificationService();
          await notificationService.registerFCMToken(
            userId: _user!.id,
            userType: 'patient',
          );
        } catch (e) {
          debugPrint('Failed to register FCM token on app start: $e');
        }
      }
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await PatientApiService.login(email, password);

      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['patient'] ?? {});

        ApiService.setAuthToken(_token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('patient_token', _token!);
        await prefs.setString('patient_id', _user!.id);
        await prefs.setString('patient_email', _user!.email);

        // Register FCM token after successful login
        try {
          final notificationService = NotificationService();
          await notificationService
              .initialize(); // Initialize notification service
          await notificationService.registerFCMToken(
            userId: _user!.id,
            userType: 'patient',
          );
        } catch (e) {
          debugPrint('Failed to register FCM token after login: $e');
        }

        _isLoading = false;
        notifyListeners();

        return {'success': true, 'message': 'Login successful'};
      }

      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': response['message'] ?? 'Login failed',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.setAuthToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('patient_token');
    await prefs.remove('patient_id');
    await prefs.remove('patient_email');

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
}
