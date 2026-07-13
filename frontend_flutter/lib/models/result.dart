class TestResult {
  final String id;
  final String orderId;
  final String testId;
  final String? patientId;
  final String testResult;
  final String? units;
  final String? referenceRange;
  final String? remarks;
  final DateTime? createdAt;

  TestResult({
    required this.id,
    required this.orderId,
    required this.testId,
    this.patientId,
    required this.testResult,
    this.units,
    this.referenceRange,
    this.remarks,
    this.createdAt,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      id: json['_id'] ?? json['id'] ?? '',
      orderId: json['order_id'] is Map
          ? json['order_id']['_id']
          : json['order_id'] ?? '',
      testId: json['test_id'] is Map
          ? json['test_id']['_id']
          : json['test_id'] ?? '',
      patientId: json['patient_id'] is Map
          ? json['patient_id']['_id']
          : json['patient_id'],
      testResult: json['test_result'] ?? '',
      units: json['units'],
      referenceRange: json['reference_range'],
      remarks: json['remarks'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'order_id': orderId,
      'test_id': testId,
      if (patientId != null) 'patient_id': patientId,
      'test_result': testResult,
      if (units != null) 'units': units,
      if (referenceRange != null) 'reference_range': referenceRange,
      if (remarks != null) 'remarks': remarks,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
