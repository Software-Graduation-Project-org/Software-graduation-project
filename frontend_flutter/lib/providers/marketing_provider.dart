import 'package:flutter/foundation.dart';
import '../models/feedback.dart';
import '../services/public_api_service.dart';
import '../services/admin_service.dart';

class MarketingProvider with ChangeNotifier {
  List<Feedback> _systemFeedback = [];
  bool _isLoading = false;
  String? _error;

  // Admin contact information
  Map<String, dynamic>? _adminContact;
  bool _isContactLoading = false;
  String? _contactError;

  List<Feedback> get systemFeedback => _systemFeedback;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic>? get adminContact => _adminContact;
  bool get isContactLoading => _isContactLoading;
  String? get contactError => _contactError;

  Future<void> loadSystemFeedback({int limit = 10, int minRating = 4}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await PublicApiService.getSystemFeedback(
        limit: limit,
        minRating: minRating,
      );

      if (response['success'] == true) {
        _systemFeedback = (response['feedback'] as List)
            .map((json) => Feedback.fromJson(json))
            .toList();
      } else {
        _error = 'Failed to load feedback';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminContactInfo() async {
    _isContactLoading = true;
    _contactError = null;
    notifyListeners();

    try {
      final response = await AdminService.getContactInfo();

      if (response['success'] == true) {
        _adminContact = response['contact'];
      } else {
        _contactError =
            response['message'] ?? 'Failed to load contact information';
      }
    } catch (e) {
      _contactError = e.toString();
    } finally {
      _isContactLoading = false;
      notifyListeners();
    }
  }
}
