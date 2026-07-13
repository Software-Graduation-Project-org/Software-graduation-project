class FullName {
  final String first;
  final String? middle;
  final String last;

  FullName({required this.first, this.middle, required this.last});

  factory FullName.fromJson(Map<String, dynamic> json) {
    return FullName(
      first: json['first'] ?? '',
      middle: json['middle'],
      last: json['last'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'first': first, if (middle != null) 'middle': middle, 'last': last};
  }
}

class User {
  final String id;
  final String email;
  final String role;
  final FullName? fullName;
  final String? phoneNumber;
  final String? employeeNumber;
  final String? professionLicense;
  final String? specialty;
  final String? identityNumber;
  final DateTime? birthday;
  final String? gender;
  final String? insuranceProvider;
  final String? insuranceNumber;
  final String? socialStatus;
  final String? labName;
  final String? username;
  final String? qualification;
  final DateTime? dateHired;

  User({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.phoneNumber,
    this.employeeNumber,
    this.professionLicense,
    this.specialty,
    this.identityNumber,
    this.birthday,
    this.gender,
    this.insuranceProvider,
    this.insuranceNumber,
    this.socialStatus,
    this.labName,
    this.username,
    this.qualification,
    this.dateHired,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      fullName: json['full_name'] != null || json['name'] != null
          ? FullName.fromJson(json['full_name'] ?? json['name'])
          : null,
      phoneNumber:
          json['phone_number'] ?? json['phone'], // Support both field names
      employeeNumber: json['employee_number'],
      professionLicense: json['profession_license'],
      specialty: json['specialty'],
      identityNumber: json['identity_number'],
      birthday: json['birthday'] != null ? _parseDate(json['birthday']) : null,
      gender: json['gender'],
      insuranceProvider: json['insurance_provider'],
      insuranceNumber: json['insurance_number'],
      socialStatus: json['social_status'],
      labName: json['lab_name'] ?? json['owner_id']?['lab_name'],
      username: json['username'],
      qualification: json['qualification'],
      dateHired: json['date_hired'] != null
          ? _parseDate(json['date_hired'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'role': role,
      if (fullName != null) 'full_name': fullName!.toJson(),
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (employeeNumber != null) 'employee_number': employeeNumber,
      if (professionLicense != null) 'profession_license': professionLicense,
      if (specialty != null) 'specialty': specialty,
      if (identityNumber != null) 'identity_number': identityNumber,
      if (birthday != null) 'birthday': birthday!.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (insuranceProvider != null) 'insurance_provider': insuranceProvider,
      if (insuranceNumber != null) 'insurance_number': insuranceNumber,
      if (socialStatus != null) 'social_status': socialStatus,
      if (labName != null) 'lab_name': labName,
      if (username != null) 'username': username,
      if (qualification != null) 'qualification': qualification,
      if (dateHired != null) 'date_hired': dateHired!.toIso8601String(),
    };
  }

  String get displayName {
    if (fullName != null) {
      final middle = fullName!.middle != null && fullName!.middle!.isNotEmpty
          ? ' ${fullName!.middle}'
          : '';
      return '${fullName!.first}$middle ${fullName!.last}';
    }
    return email;
  }

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        // Try parsing different formats
        try {
          // Handle date-only strings like "1994-09-04"
          if (dateValue.length == 10 && dateValue.contains('-')) {
            return DateTime.parse('${dateValue}T00:00:00.000Z');
          }
          // Handle DD/MM/YYYY format like "09/04/1994"
          if (dateValue.length == 10 && dateValue.contains('/')) {
            final parts = dateValue.split('/');
            if (parts.length == 3) {
              final day = int.tryParse(parts[0]);
              final month = int.tryParse(parts[1]);
              final year = int.tryParse(parts[2]);
              if (day != null && month != null && year != null) {
                return DateTime(year, month, day);
              }
            }
          }
        } catch (e2) {
          // Ignore parsing errors
        }
        return null;
      }
    }

    if (dateValue is DateTime) {
      return dateValue;
    }

    return null;
  }
}
