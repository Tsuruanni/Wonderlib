import '../../../domain/repositories/teacher_repository.dart';

/// Model for TeacherStats - handles JSON serialization
class TeacherStatsModel {

  const TeacherStatsModel({
    required this.totalStudents,
    required this.totalClasses,
    required this.activeAssignments,
    required this.avgProgress,
  });

  factory TeacherStatsModel.fromJson(Map<String, dynamic> json) {
    return TeacherStatsModel(
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalClasses: (json['total_classes'] as num?)?.toInt() ?? 0,
      activeAssignments: (json['active_assignments'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
    );
  }

  final int totalStudents;
  final int totalClasses;
  final int activeAssignments;
  final double avgProgress;

  TeacherStats toEntity() {
    return TeacherStats(
      totalStudents: totalStudents,
      totalClasses: totalClasses,
      activeAssignments: activeAssignments,
      avgProgress: avgProgress,
    );
  }
}
