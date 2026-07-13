class Device {
  final String id;
  final String name;
  final String serialNumber;
  final String? manufacturer;
  final String? model;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpiry;
  final String status; // 'active', 'inactive', 'maintenance'
  final String? staffId;
  final String ownerId;
  final DateTime? createdAt;

  Device({
    required this.id,
    required this.name,
    required this.serialNumber,
    this.manufacturer,
    this.model,
    this.purchaseDate,
    this.warrantyExpiry,
    this.status = 'active',
    this.staffId,
    required this.ownerId,
    this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      serialNumber: json['serial_number'] ?? '',
      manufacturer: json['manufacturer'],
      model: json['model'],
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'])
          : null,
      warrantyExpiry: json['warranty_expiry'] != null
          ? DateTime.parse(json['warranty_expiry'])
          : null,
      status: json['status'] ?? 'active',
      staffId: json['staff_id'] is Map
          ? json['staff_id']['_id']
          : json['staff_id'],
      ownerId: json['owner_id'] is Map
          ? json['owner_id']['_id']
          : json['owner_id'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'serial_number': serialNumber,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (purchaseDate != null)
        'purchase_date': purchaseDate!.toIso8601String(),
      if (warrantyExpiry != null)
        'warranty_expiry': warrantyExpiry!.toIso8601String(),
      'status': status,
      if (staffId != null) 'staff_id': staffId,
      'owner_id': ownerId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  bool get isActive => status == 'active';
  bool get needsMaintenance => status == 'maintenance';
}
