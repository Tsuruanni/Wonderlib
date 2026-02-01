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

  factory TeacherStatsModel.fromEntity(TeacherStats entity) {
    return TeacherStatsModel(
      totalStudents: entity.totalStudents,
      totalClasses: entity.totalClasses,
      activeAssignments: entity.activeAssignments,
      avgProgress: entity.avgProgress,
    );
  }
  final int totalStudents;
  final int totalClasses;
  final int activeAssignments;
  final double avgProgress;

  Map<String, dynamic> toJson() {
    return {
      'total_students': totalStudents,
      'total_classes': totalClasses,
      'active_assignments': activeAssignments,
      'avg_progress': avgProgress,
    };
  }

  TeacherStats toEntity() {
    return TeacherStats(
      totalStudents: totalStudents,
      totalClasses: totalClasses,
      activeAssignments: activeAssignments,
      avgProgress: avgProgress,
    );
  }
}
