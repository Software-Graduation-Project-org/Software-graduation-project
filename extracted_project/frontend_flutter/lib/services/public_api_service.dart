import 'api_service.dart';

class PublicApiService {
  // Submit lab owner registration with plan info
  static Future<Map<String, dynamic>> submitOwnerRegistration({
    required String firstName,
    required String middleName,
    required String lastName,
    required String identityNumber,
    required String birthday,
    required String gender,
    required String phone,
    required String address,
    required String email,
    required String selectedPlan,
    required String labName,
    required String labLicenseNumber,
    String? socialStatus,
    String? qualification,
    String? professionLicense,
    String? bankIban,
    String? subscriptionEndDate,
  }) async {
    // Parse address into components for the API
    final addressParts = address.split(', ');
    final addressMap = {
      'city': addressParts.isNotEmpty ? addressParts[0] : '',
      'street': addressParts.length > 1 ? addressParts[1] : '',
      'building_number': addressParts.length > 2 ? addressParts[2] : '',
    };

    return await ApiService.post('/public/owner/register', {
      'full_name': {'first': firstName, 'middle': middleName, 'last': lastName},
      'identity_number': identityNumber,
      'birthday': birthday,
      'gender': gender,
      'phone_number': phone,
      'email': email,
      'address': addressMap,
      'lab_name': labName,
      'lab_license_number': labLicenseNumber,
      'subscription_tier': selectedPlan,
      'subscription_period_months': 1,
      if (subscriptionEndDate != null && subscriptionEndDate.isNotEmpty)
        'subscription_end_date': subscriptionEndDate,
    });
  }

  // Get available subscription tiers
  static Future<Map<String, dynamic>> getSubscriptionTiers() async {
    return await ApiService.get('/public/subscription-tiers');
  }

  // Submit registration (get token)
  static Future<Map<String, dynamic>> submitRegistration({
    required String labId,
    required Map<String, dynamic>
    fullName, // {first: String, middle: String?, last: String}
    required String identityNumber,
    required String birthday,
    required String gender,
    required String phoneNumber,
    required String email,
    required String address,
    required List<String> testIds,
    String? socialStatus,
    String? insuranceProvider,
    String? insuranceNumber,
    String? remarks,
  }) async {
    return await ApiService.post('/public/submit-registration', {
      'lab_id': labId,
      'full_name': fullName,
      'identity_number': identityNumber,
      'birthday': birthday,
      'gender': gender,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'test_ids': testIds,
      if (socialStatus != null) 'social_status': socialStatus,
      if (insuranceProvider != null) 'insurance_provider': insuranceProvider,
      if (insuranceNumber != null) 'insurance_number': insuranceNumber,
      if (remarks != null) 'remarks': remarks,
    });
  }

  // Verify registration token
  static Future<Map<String, dynamic>> verifyToken(String token) async {
    return await ApiService.get('/public/register/verify/$token');
  }

  // Complete registration
  static Future<Map<String, dynamic>> completeRegistration({
    required String token,
    required String password,
    required Map<String, dynamic> personalInfo,
  }) async {
    return await ApiService.post('/public/register/complete', {
      'token': token,
      'password': password,
      ...personalInfo,
    });
  }

  // Get labs
  static Future<Map<String, dynamic>> getLabs() async {
    return await ApiService.get('/public/labs');
  }

  // Get lab tests
  static Future<Map<String, dynamic>> getLabTests(String labId) async {
    return await ApiService.get('/public/labs/$labId/tests');
  }

  // Get system feedback for marketing
  static Future<Map<String, dynamic>> getSystemFeedback({
    int limit = 10,
    int minRating = 4,
  }) async {
    return await ApiService.get(
      '/public/feedback/system?limit=$limit&minRating=$minRating',
    );
  }

  // Submit contact form for laboratory owners interested in the system
  static Future<Map<String, dynamic>> submitContactForm({
    required String name,
    required String email,
    String? phone,
    required String labName,
    required String message,
  }) async {
    return await ApiService.post('/public/contact', {
      'name': name,
      'email': email,
      'phone': phone,
      'lab_name': labName,
      'message': message,
    });
  }

  // Register new lab owner (self-service registration)
  static Future<Map<String, dynamic>> registerOwner({
    required Map<String, String> fullName, // {first, middle, last}
    required String identityNumber,
    required String birthday,
    required String gender,
    required String phoneNumber,
    required String email,
    required Map<String, String> address, // {city, street, building_number}
    required String labName,
    required String labLicenseNumber,
    required String username,
    required String password,
    int subscriptionPeriodMonths = 1, // Default 1 month
  }) async {
    return await ApiService.post('/public/owner/register', {
      'full_name': fullName,
      'identity_number': identityNumber,
      'birthday': birthday,
      'gender': gender,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'lab_name': labName,
      'lab_license_number': labLicenseNumber,
      'username': username,
      'password': password,
      'subscription_period_months': subscriptionPeriodMonths,
    });
  }

  // Get all available labs for public lab finder
  static Future<Map<String, dynamic>> getAllLabs() async {
    return await ApiService.get('/public/labs');
  }
}
