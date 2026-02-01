import '../../../domain/repositories/teacher_repository.dart';

/// Model for AssignmentStudent - handles JSON serialization
class AssignmentStudentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final String status;
  final double progress;
  final double? score;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const AssignmentStudentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.status,
    required this.progress,
    this.score,
    this.startedAt,
    this.completedAt,
  });

  factory AssignmentStudentModel.fromJson(Map<String, dynamic> json) {
    final profileData = json['profiles'] as Map<String, dynamic>?;
    final firstName = profileData?['first_name'] as String? ?? '';
    final lastName = profileData?['last_name'] as String? ?? '';

    return AssignmentStudentModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: '$firstName $lastName'.trim(),
      avatarUrl: profileData?['avatar_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      score: (json['score'] as num?)?.toDouble(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'avatar_url': avatarUrl,
      'status': status,
      'progress': progress,
      'score': score,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  AssignmentStudent toEntity() {
    return AssignmentStudent(
      id: id,
      studentId: studentId,
      studentName: studentName,
      avatarUrl: avatarUrl,
      status: AssignmentStatus.fromString(status),
      progress: progress,
      score: score,
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }

  factory AssignmentStudentModel.fromEntity(AssignmentStudent entity) {
    return AssignmentStudentModel(
      id: entity.id,
      studentId: entity.studentId,
      studentName: entity.studentName,
      avatarUrl: entity.avatarUrl,
      status: _statusToString(entity.status),
      progress: entity.progress,
      score: entity.score,
      startedAt: entity.startedAt,
      completedAt: entity.completedAt,
    );
  }

  static String _statusToString(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return 'pending';
      case AssignmentStatus.inProgress:
        return 'in_progress';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.overdue:
        return 'overdue';
    }
  }
}
