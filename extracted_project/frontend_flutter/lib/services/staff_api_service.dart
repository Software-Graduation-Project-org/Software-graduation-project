import 'api_service.dart';

class StaffApiService {
  // Auth
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    return await ApiService.post('/staff/login', {
      'username': username,
      'password': password,
    });
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiService.get('/staff/profile');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await ApiService.put('/staff/profile', profileData);
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await ApiService.put('/staff/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // Dashboard & Assigned Tests
  static Future<Map<String, dynamic>> getMyAssignedTests({
    String? statusFilter,
    String? deviceId,
  }) async {
    var url = '/staff/my-assigned-tests';
    final params = <String>[];

    if (statusFilter != null) params.add('status_filter=$statusFilter');
    if (deviceId != null) params.add('device_id=$deviceId');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    return await ApiService.get(url);
  }

  // Get all tests available in the staff's lab
  static Future<Map<String, dynamic>> getLabTests() async {
    return await ApiService.get('/staff/lab-tests');
  }

  // Get unassigned tests for staff to assign themselves to
  static Future<Map<String, dynamic>> getMyUnassignedTests() async {
    return await ApiService.get('/staff/my-unassigned-tests');
  }

  // Assign staff to a specific test
  static Future<Map<String, dynamic>> assignToTest({
    required String detailId,
  }) async {
    return await ApiService.post('/staff/assign-to-test', {
      'detail_id': detailId,
    });
  }

  // Search patients
  static Future<Map<String, dynamic>> searchPatients(String query) async {
    return await ApiService.get('/staff/patients/search?query=$query');
  }

  // Create walk-in order
  static Future<Map<String, dynamic>> createWalkInOrder({
    required Map<String, dynamic> patientInfo,
    required List<String> testIds,
    String? doctorId,
  }) async {
    return await ApiService.post('/staff/create-walk-in-order', {
      'patient_info': patientInfo,
      'test_ids': testIds,
      if (doctorId != null) 'doctor_id': doctorId,
    });
  }

  // Get pending orders
  static Future<Map<String, dynamic>> getPendingOrders() async {
    return await ApiService.get('/staff/pending-orders');
  }

  // Get all orders for the lab
  static Future<Map<String, dynamic>> getAllLabOrders({
    String? status,
    String? patientId,
    String? startDate,
    String? endDate,
  }) async {
    // print(
    //   '🔍 DEBUG: API getAllLabOrders called with status: $status, patientId: $patientId, startDate: $startDate, endDate: $endDate',
    // );
    var url = '/staff/orders';
    final params = <String>[];

    if (status != null) params.add('status=$status');
    if (patientId != null) params.add('patient_id=$patientId');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    // print('🔍 DEBUG: API getAllLabOrders - final URL: $url');
    final result = await ApiService.get(url);
    // print('🔍 DEBUG: API getAllLabOrders - result: $result');
    return result;
  }

  // Sample Collection
  static Future<Map<String, dynamic>> collectSample({
    required String detailId,
  }) async {
    return await ApiService.post('/staff/collect-sample', {
      'detail_id': detailId,
    });
  }

  // Auto-assign tests
  static Future<Map<String, dynamic>> autoAssignTests({
    required String orderId,
  }) async {
    return await ApiService.post('/staff/auto-assign-tests', {
      'order_id': orderId,
    });
  }

  // Result Upload
  static Future<Map<String, dynamic>> uploadResult({
    required String detailId,
    String? resultValue,
    List<Map<String, dynamic>>? components,
    String? remarks,
  }) async {
    // print('🔍 API SERVICE DEBUG: uploadResult called with:');
    // print('🔍 API SERVICE DEBUG: detailId: $detailId');
    // print('🔍 API SERVICE DEBUG: resultValue: $resultValue');
    // print('🔍 API SERVICE DEBUG: components: $components');
    // print('🔍 API SERVICE DEBUG: remarks: $remarks');

    final requestData = {
      'detail_id': detailId,
      if (resultValue != null) 'result_value': resultValue,
      if (components != null) 'components': components,
      if (remarks != null) 'remarks': remarks,
    };

    // print('🔍 API SERVICE DEBUG: Sending request data: $requestData');

    return await ApiService.post('/staff/upload-result', requestData);
  }

  // Get test components (for multi-component tests)
  static Future<Map<String, dynamic>> getTestComponents(String testId) async {
    return await ApiService.get('/staff/tests/$testId/components');
  }

  // Run HL7 simulation for automated result generation (now runs in background)
  static Future<Map<String, dynamic>> runTest({
    required String detailId,
    String priority = 'normal',
  }) async {
    return await ApiService.post('/staff/run-test', {
      'detail_id': detailId,
      'priority': priority,
    });
  }

  // Notifications
  static Future<List<dynamic>> getNotifications(String staffId) async {
    final response = await ApiService.get('/staff/notifications/$staffId');
    // The backend returns the notifications array directly
    return response as List<dynamic>;
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(
    String staffId,
    String notificationId,
  ) async {
    return await ApiService.put(
      '/staff/notifications/$staffId/$notificationId/read',
      {},
    );
  }

  // Inventory
  static Future<Map<String, dynamic>> getInventoryItems({
    int page = 1,
    int limit = 20,
  }) async {
    final params = 'page=$page&limit=$limit';
    return await ApiService.get('/staff/inventory?$params');
  }

  static Future<Map<String, dynamic>> reportInventoryIssue({
    required String inventoryId,
    required String issueType,
    required int quantity,
    String? description,
  }) async {
    return await ApiService.post('/staff/report-inventory-issue', {
      'inventory_id': inventoryId,
      'issue_type': issueType,
      'quantity': quantity,
      if (description != null) 'description': description,
    });
  }

  static Future<Map<String, dynamic>> consumeInventory({
    required String inventoryId,
    required int quantity,
    String? reason,
  }) async {
    return await ApiService.post('/staff/consume-inventory', {
      'inventory_id': inventoryId,
      'quantity': quantity,
      if (reason != null) 'reason': reason,
    });
  }

  // Feedback
  static Future<Map<String, dynamic>> provideFeedback({
    required String targetType,
    String? targetId,
    required int rating,
    required String message,
    bool isAnonymous = false,
  }) async {
    return await ApiService.post('/staff/feedback', {
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

    return await ApiService.get('/staff/feedback?$queryString');
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
    final queryParams = <String, String>{};
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (status != null) queryParams['status'] = status;
    if (patientName != null) queryParams['patientName'] = patientName;
    if (testName != null) queryParams['testName'] = testName;

    return await ApiService.get('/staff/results', params: queryParams);
  }

  // Get tests ready for result upload
  static Future<Map<String, dynamic>> getTestsForResultUpload({
    int page = 1,
    int limit = 50,
    String? patientName,
    String? testName,
  }) async {
    final queryParams = <String, String>{};
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    if (patientName != null) queryParams['patientName'] = patientName;
    if (testName != null) queryParams['testName'] = testName;

    return await ApiService.get('/staff/tests-for-upload', params: queryParams);
  }

  static Future<Map<String, dynamic>> getAllInvoices({
    int page = 1,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? status,
    String? patientName,
  }) async {
    final queryParams = <String, String>{};
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (status != null) queryParams['status'] = status;
    if (patientName != null) queryParams['patientName'] = patientName;

    return await ApiService.get('/staff/invoices', params: queryParams);
  }

  // Get order results report (same as patient view)
  static Future<Map<String, dynamic>> getOrderResultsReport(
    String orderId,
  ) async {
    // print('🔍 DEBUG: API call - getOrderResultsReport for orderId: $orderId');
    return await ApiService.get('/staff/orders/$orderId/results');
  }

  // Get invoice details (same as patient view)
  static Future<Map<String, dynamic>> getInvoiceDetails(
    String invoiceId,
  ) async {
    // print('🔍 DEBUG: API call - getInvoiceDetails for invoiceId: $invoiceId');
    return await ApiService.get('/staff/invoices/$invoiceId/details');
  }

  // Get invoice by order ID
  static Future<Map<String, dynamic>> getInvoiceByOrderId(
    String orderId,
  ) async {
    // print('🔍 DEBUG: API call - getInvoiceByOrderId for orderId: $orderId');
    return await ApiService.get('/staff/orders/$orderId/invoice');
  }

  // Test Assignment
  static Future<Map<String, dynamic>> assignTestToMe(String detailId) async {
    return await ApiService.post('/staff/assign-test-to-me', {
      'detail_id': detailId,
    });
  }

  // Get doctors for the lab
  static Future<Map<String, dynamic>> getLabDoctors() async {
    return await ApiService.get('/staff/doctors');
  }

  // WhatsApp Direct Messaging
  static Future<Map<String, dynamic>> sendWhatsAppMessage(
    String phoneNumber,
    String message,
  ) async {
    return await ApiService.post('/staff/send-whatsapp', {
      'phone_number': phoneNumber,
      'message': message,
    });
  }
}
