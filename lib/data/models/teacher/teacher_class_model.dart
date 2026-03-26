import '../../../domain/repositories/teacher_repository.dart';

/// Model for TeacherClass - handles JSON serialization
class TeacherClassModel {

  const TeacherClassModel({
    required this.id,
    required this.name,
    required this.grade,
    this.academicYear,
    required this.studentCount,
    required this.avgProgress,
    this.avgXp = 0,
    this.avgStreak = 0,
    this.totalReadingTime = 0,
    this.completedBooks = 0,
    this.activeLast30d = 0,
    this.totalVocabWords = 0,
    this.createdAt,
  });

  factory TeacherClassModel.fromJson(Map<String, dynamic> json) {
    return TeacherClassModel(
      id: json['id'] as String,
      name: json['name'] as String,
      grade: (json['grade'] as num?)?.toInt() ?? 0,
      academicYear: json['academic_year'] as String?,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      avgXp: (json['avg_xp'] as num?)?.toDouble() ?? 0,
      avgStreak: (json['avg_streak'] as num?)?.toDouble() ?? 0,
      totalReadingTime: (json['total_reading_time'] as num?)?.toInt() ?? 0,
      completedBooks: (json['completed_books'] as num?)?.toInt() ?? 0,
      activeLast30d: (json['active_last_30d'] as num?)?.toInt() ?? 0,
      totalVocabWords: (json['total_vocab_words'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  factory TeacherClassModel.fromEntity(TeacherClass entity) {
    return TeacherClassModel(
      id: entity.id,
      name: entity.name,
      grade: entity.grade,
      academicYear: entity.academicYear,
      studentCount: entity.studentCount,
      avgProgress: entity.avgProgress,
      avgXp: entity.avgXp,
      avgStreak: entity.avgStreak,
      totalReadingTime: entity.totalReadingTime,
      completedBooks: entity.completedBooks,
      activeLast30d: entity.activeLast30d,
      totalVocabWords: entity.totalVocabWords,
      createdAt: entity.createdAt,
    );
  }

  final String id;
  final String name;
  final int grade;
  final String? academicYear;
  final int studentCount;
  final double avgProgress;
  final double avgXp;
  final double avgStreak;
  final int totalReadingTime;
  final int completedBooks;
  final int activeLast30d;
  final int totalVocabWords;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'academic_year': academicYear,
      'student_count': studentCount,
      'avg_progress': avgProgress,
      'avg_xp': avgXp,
      'avg_streak': avgStreak,
      'total_reading_time': totalReadingTime,
      'completed_books': completedBooks,
      'active_last_30d': activeLast30d,
      'total_vocab_words': totalVocabWords,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  TeacherClass toEntity() {
    return TeacherClass(
      id: id,
      name: name,
      grade: grade,
      academicYear: academicYear,
      studentCount: studentCount,
      avgProgress: avgProgress,
      avgXp: avgXp,
      avgStreak: avgStreak,
      totalReadingTime: totalReadingTime,
      completedBooks: completedBooks,
      activeLast30d: activeLast30d,
      totalVocabWords: totalVocabWords,
      createdAt: createdAt,
    );
  }
}
