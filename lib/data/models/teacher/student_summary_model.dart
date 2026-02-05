import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentSummary - handles JSON serialization
class StudentSummaryModel {

  const StudentSummaryModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.studentNumber,
    this.email,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.booksRead,
    required this.avgProgress,
  });

  factory StudentSummaryModel.fromJson(Map<String, dynamic> json) {
    return StudentSummaryModel(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      studentNumber: json['student_number'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentStreak: (json['streak'] as num?)?.toInt() ?? 0,
      booksRead: (json['books_read'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
    );
  }

  factory StudentSummaryModel.fromEntity(StudentSummary entity) {
    return StudentSummaryModel(
      id: entity.id,
      firstName: entity.firstName,
      lastName: entity.lastName,
      studentNumber: entity.studentNumber,
      email: entity.email,
      avatarUrl: entity.avatarUrl,
      xp: entity.xp,
      level: entity.level,
      currentStreak: entity.currentStreak,
      booksRead: entity.booksRead,
      avgProgress: entity.avgProgress,
    );
  }
  final String id;
  final String firstName;
  final String lastName;
  final String? studentNumber;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int currentStreak;
  final int booksRead;
  final double avgProgress;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'student_number': studentNumber,
      'email': email,
      'avatar_url': avatarUrl,
      'xp': xp,
      'level': level,
      'streak': currentStreak,
      'books_read': booksRead,
      'avg_progress': avgProgress,
    };
  }

  StudentSummary toEntity() {
    return StudentSummary(
      id: id,
      firstName: firstName,
      lastName: lastName,
      studentNumber: studentNumber,
      email: email,
      avatarUrl: avatarUrl,
      xp: xp,
      level: level,
      currentStreak: currentStreak,
      booksRead: booksRead,
      avgProgress: avgProgress,
    );
  }
}
