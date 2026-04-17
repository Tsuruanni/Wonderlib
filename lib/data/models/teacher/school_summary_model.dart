import '../../../domain/entities/teacher.dart';

class SchoolSummaryModel {
  const SchoolSummaryModel({
    required this.totalStudents,
    required this.activeLast30d,
    required this.totalXp,
    required this.avgXp,
    required this.avgStreak,
    required this.avgProgress,
    required this.totalReadingTime,
    required this.totalBooksRead,
    required this.totalVocabWords,
  });

  factory SchoolSummaryModel.fromJson(Map<String, dynamic> json) {
    return SchoolSummaryModel(
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeLast30d: (json['active_last_30d'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      avgXp: (json['avg_xp'] as num?)?.toDouble() ?? 0,
      avgStreak: (json['avg_streak'] as num?)?.toDouble() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      totalReadingTime: (json['total_reading_time'] as num?)?.toInt() ?? 0,
      totalBooksRead: (json['total_books_read'] as num?)?.toInt() ?? 0,
      totalVocabWords: (json['total_vocab_words'] as num?)?.toInt() ?? 0,
    );
  }

  final int totalStudents;
  final int activeLast30d;
  final int totalXp;
  final double avgXp;
  final double avgStreak;
  final double avgProgress;
  final int totalReadingTime;
  final int totalBooksRead;
  final int totalVocabWords;

  SchoolSummary toEntity() => SchoolSummary(
        totalStudents: totalStudents,
        activeLast30d: activeLast30d,
        totalXp: totalXp,
        avgXp: avgXp,
        avgStreak: avgStreak,
        avgProgress: avgProgress,
        totalReadingTime: totalReadingTime,
        totalBooksRead: totalBooksRead,
        totalVocabWords: totalVocabWords,
      );
}
