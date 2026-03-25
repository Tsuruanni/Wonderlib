import '../../../domain/repositories/teacher_repository.dart';

/// Model for RecentActivity - handles JSON serialization
class RecentActivityModel {
  const RecentActivityModel({
    required this.studentId,
    required this.studentFirstName,
    required this.studentLastName,
    this.avatarUrl,
    required this.activityType,
    required this.description,
    required this.xpAmount,
    required this.createdAt,
  });

  factory RecentActivityModel.fromJson(Map<String, dynamic> json) {
    return RecentActivityModel(
      studentId: json['student_id'] as String,
      studentFirstName: json['student_first_name'] as String? ?? '',
      studentLastName: json['student_last_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      activityType: json['activity_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      xpAmount: (json['xp_amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String studentId;
  final String studentFirstName;
  final String studentLastName;
  final String? avatarUrl;
  final String activityType;
  final String description;
  final int xpAmount;
  final DateTime createdAt;

  RecentActivity toEntity() {
    return RecentActivity(
      studentId: studentId,
      studentFirstName: studentFirstName,
      studentLastName: studentLastName,
      avatarUrl: avatarUrl,
      activityType: activityType,
      description: description,
      xpAmount: xpAmount,
      createdAt: createdAt,
    );
  }
}
