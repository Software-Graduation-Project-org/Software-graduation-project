class Order {
  final String id;
  final String? patientId;
  final String? doctorId;
  final String ownerId;
  final String status;
  final DateTime orderDate;
  final List<String> tests;
  final double? totalAmount;
  final String? registrationToken;
  final DateTime? registrationTokenExpires;
  final bool isPaid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    this.patientId,
    this.doctorId,
    required this.ownerId,
    this.status = 'pending',
    required this.orderDate,
    this.tests = const [],
    this.totalAmount,
    this.registrationToken,
    this.registrationTokenExpires,
    this.isPaid = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? json['id'] ?? '',
      patientId: json['patient_id'] is Map
          ? json['patient_id']['_id']
          : json['patient_id'],
      doctorId: json['doctor_id'] is Map
          ? json['doctor_id']['_id']
          : json['doctor_id'],
      ownerId: json['owner_id'] is Map
          ? json['owner_id']['_id']
          : json['owner_id'] ?? '',
      status: json['status'] ?? 'pending',
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'])
          : DateTime.now(),
      tests: json['tests'] != null
          ? (json['tests'] as List).map((t) => t.toString()).toList()
          : [],
      totalAmount: json['total_amount']?.toDouble(),
      registrationToken: json['registration_token'],
      registrationTokenExpires: json['registration_token_expires'] != null
          ? DateTime.parse(json['registration_token_expires'])
          : null,
      isPaid: json['is_paid'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (patientId != null) 'patient_id': patientId,
      if (doctorId != null) 'doctor_id': doctorId,
      'owner_id': ownerId,
      'status': status,
      'order_date': orderDate.toIso8601String(),
      'tests': tests,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (registrationToken != null) 'registration_token': registrationToken,
      if (registrationTokenExpires != null)
        'registration_token_expires': registrationTokenExpires!
            .toIso8601String(),
      'is_paid': isPaid,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

class OrderDetails {
  final String id;
  final String orderId;
  final String testId;
  final String? deviceId;
  final String? staffId;
  final DateTime? assignedAt;
  final bool sampleCollected;
  final DateTime? sampleCollectedDate;
  final String status;
  final String? resultId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Populated fields (when fetched with populate)
  final Map<String, dynamic>? test;
  final Map<String, dynamic>? device;

  OrderDetails({
    required this.id,
    required this.orderId,
    required this.testId,
    this.deviceId,
    this.staffId,
    this.assignedAt,
    this.sampleCollected = false,
    this.sampleCollectedDate,
    this.status = 'pending',
    this.resultId,
    this.createdAt,
    this.updatedAt,
    this.test,
    this.device,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    return OrderDetails(
      id: json['_id'] ?? json['id'] ?? '',
      orderId: json['order_id'] is Map
          ? json['order_id']['_id']
          : json['order_id'] ?? '',
      testId: json['test_id'] is Map
          ? json['test_id']['_id']
          : json['test_id'] ?? '',
      deviceId: json['device_id'] is Map
          ? json['device_id']['_id']
          : json['device_id'],
      staffId: json['staff_id'] is Map
          ? json['staff_id']['_id']
          : json['staff_id'],
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : null,
      sampleCollected: json['sample_collected'] ?? false,
      sampleCollectedDate: json['sample_collected_date'] != null
          ? DateTime.parse(json['sample_collected_date'])
          : null,
      status: json['status'] ?? 'pending',
      resultId: json['result_id'] is Map
          ? json['result_id']['_id']
          : json['result_id'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      test: json['test_id'] is Map ? json['test_id'] : null,
      device: json['device_id'] is Map ? json['device_id'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'order_id': orderId,
      'test_id': testId,
      if (deviceId != null) 'device_id': deviceId,
      if (staffId != null) 'staff_id': staffId,
      if (assignedAt != null) 'assigned_at': assignedAt!.toIso8601String(),
      'sample_collected': sampleCollected,
      if (sampleCollectedDate != null)
        'sample_collected_date': sampleCollectedDate!.toIso8601String(),
      'status': status,
      if (resultId != null) 'result_id': resultId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isUrgent => status == 'urgent';
  bool get isAssigned => staffId != null;
}
