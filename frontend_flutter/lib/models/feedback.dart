class Feedback {
  final String id;
  final String userId;
  final String userModel;
  final String targetType;
  final String targetId;
  final int rating;
  final String? message;
  final bool isAnonymous;
  final String? response;
  final DateTime? responseDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated fields (from API)
  final Map<String, dynamic>? target;
  final Map<String, dynamic>? user;
  final String? userName; // Direct user name from backend

  Feedback({
    required this.id,
    required this.userId,
    required this.userModel,
    required this.targetType,
    required this.targetId,
    required this.rating,
    this.message,
    this.isAnonymous = false,
    this.response,
    this.responseDate,
    required this.createdAt,
    required this.updatedAt,
    this.target,
    this.user,
    this.userName,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userModel: json['user_model'] ?? '',
      targetType: json['target_type'] ?? '',
      targetId: json['target_id'] ?? '',
      rating: json['rating'] ?? 0,
      message: json['message'],
      isAnonymous: json['is_anonymous'] is bool
          ? json['is_anonymous']
          : json['is_anonymous'] == 'false' || json['is_anonymous'] == false
          ? false
          : true,
      response: json['response'],
      responseDate: json['response_date'] != null
          ? DateTime.parse(json['response_date'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      target: json['target'],
      user: json['user'],
      userName: json['user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user_id': userId,
      'user_model': userModel,
      'target_type': targetType,
      'target_id': targetId,
      'rating': rating,
      'message': message,
      'is_anonymous': isAnonymous,
      'response': response,
      'response_date': responseDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  String get targetDisplayName {
    if (target == null) return 'Unknown $targetType';

    switch (targetType) {
      case 'lab':
        return target!['lab_name'] ?? target!['name'] ?? 'Unknown Lab';
      case 'test':
        return target!['test_name'] ?? 'Unknown Test';
      case 'order':
        return 'Order ${target!['_id'] ?? targetId}';
      case 'system':
        return 'Medical Lab System';
      default:
        return 'Unknown $targetType';
    }
  }

  String get ratingStars {
    return '⭐' * rating;
  }

  bool get hasResponse => response != null && response!.isNotEmpty;

  static const List<String> targetTypes = ['lab', 'test', 'order', 'system'];

  static String getTargetTypeDisplayName(String targetType) {
    switch (targetType) {
      case 'lab':
        return 'Laboratory';
      case 'test':
        return 'Medical Test';
      case 'order':
        return 'Test Order';
      case 'system':
        return 'Medical Lab System';
      default:
        return targetType[0].toUpperCase() + targetType.substring(1);
    }
  }
}
