class Lab {
  final String id;
  final String labName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final bool subscriptionActive;
  final DateTime? createdAt;

  Lab({
    required this.id,
    required this.labName,
    this.email,
    this.phoneNumber,
    this.address,
    this.subscriptionActive = true,
    this.createdAt,
  });

  factory Lab.fromJson(Map<String, dynamic> json) {
    // Handle address - it can be a string or an object
    String? addressString;
    if (json['address'] is String) {
      addressString = json['address'];
    } else if (json['address'] is Map<String, dynamic>) {
      final addressObj = json['address'] as Map<String, dynamic>;
      final parts = <String>[];
      if (addressObj['street'] != null) parts.add(addressObj['street']);
      if (addressObj['city'] != null) parts.add(addressObj['city']);
      if (addressObj['country'] != null) parts.add(addressObj['country']);
      addressString = parts.isNotEmpty ? parts.join(', ') : null;
    }

    return Lab(
      id: json['_id'] ?? json['id'] ?? '',
      labName: json['lab_name'] ?? '',
      email: json['email'],
      phoneNumber: json['phone_number'],
      address: addressString,
      subscriptionActive: json['subscription_active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'lab_name': labName,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (address != null) 'address': address,
      'subscription_active': subscriptionActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
