import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/owner_api_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';

class OwnerAuthProvider extends ChangeNotifier {
  String? _token;
  User? _user;
  bool _isLoading = false;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('owner_token');

    final userId = prefs.getString('owner_id');
    final userEmail = prefs.getString('owner_email');

    if (_token != null && userId != null && userEmail != null) {
      _user = User(id: userId, email: userEmail, role: 'Owner');

      // Clear other auth tokens to ensure single user session
      await _clearOtherAuthTokens(prefs, 'owner');

      // Only set global token if not already set
      if (ApiService.authToken == null) {
        ApiService.setAuthToken(_token);
      }

      // Register FCM token if user is already logged in
      if (!kIsWeb) {
        try {
          final notificationService = NotificationService();
          await notificationService.registerFCMToken(
            userId: _user!.id,
            userType: 'owner',
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
      final response = await OwnerApiService.login(email, password);

      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['owner'] ?? {});

        await ApiService.saveAndSetToken(_token!);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('owner_id', _user!.id);
        await prefs.setString('owner_email', _user!.email);

        // Register FCM token after successful login
        if (!kIsWeb) {
          try {
            final notificationService = NotificationService();
            await notificationService.registerFCMToken(
              userId: _user!.id,
              userType: 'owner',
            );
          } catch (e) {
            debugPrint('Failed to register FCM token on login: $e');
          }
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
    await prefs.remove('owner_token');
    await prefs.remove('owner_id');
    await prefs.remove('owner_email');

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
