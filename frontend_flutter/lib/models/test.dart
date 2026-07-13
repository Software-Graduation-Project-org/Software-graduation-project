class Test {
  final String id;
  final String testCode;
  final String testName;
  final String? sampleType;
  final String? tubeType;
  final bool isActive;
  final String? deviceId;
  final String method; // 'manual' or 'device'
  final String? units;
  final String? referenceRange;
  final double? price;
  final String ownerId;
  final String? turnaroundTime;
  final String? collectionTime;
  final String? reagent;
  final DateTime? createdAt;

  Test({
    required this.id,
    required this.testCode,
    required this.testName,
    this.sampleType,
    this.tubeType,
    this.isActive = true,
    this.deviceId,
    this.method = 'manual',
    this.units,
    this.referenceRange,
    this.price,
    required this.ownerId,
    this.turnaroundTime,
    this.collectionTime,
    this.reagent,
    this.createdAt,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['_id'] ?? json['id'] ?? '',
      testCode: json['test_code'] ?? '',
      testName: json['test_name'] ?? '',
      sampleType: json['sample_type'],
      tubeType: json['tube_type'],
      isActive: json['is_active'] ?? true,
      deviceId: json['device_id'] is Map
          ? json['device_id']['_id']
          : json['device_id'],
      method: json['method'] ?? 'manual',
      units: json['units'],
      referenceRange: json['reference_range'],
      price: json['price']?.toDouble(),
      ownerId: json['owner_id'] is Map
          ? json['owner_id']['_id']
          : json['owner_id'] ?? '',
      turnaroundTime: json['turnaround_time'],
      collectionTime: json['collection_time'],
      reagent: json['reagent'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'test_code': testCode,
      'test_name': testName,
      if (sampleType != null) 'sample_type': sampleType,
      if (tubeType != null) 'tube_type': tubeType,
      'is_active': isActive,
      if (deviceId != null) 'device_id': deviceId,
      'method': method,
      if (units != null) 'units': units,
      if (referenceRange != null) 'reference_range': referenceRange,
      if (price != null) 'price': price,
      'owner_id': ownerId,
      if (turnaroundTime != null) 'turnaround_time': turnaroundTime,
      if (collectionTime != null) 'collection_time': collectionTime,
      if (reagent != null) 'reagent': reagent,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
