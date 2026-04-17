import '../../../domain/entities/teacher.dart';

class GlobalAveragesModel {
  const GlobalAveragesModel({
    required this.avgXp,
    required this.avgStreak,
    required this.avgProgress,
    required this.avgReadingTime,
    required this.avgBooksRead,
  });

  factory GlobalAveragesModel.fromJson(Map<String, dynamic> json) {
    return GlobalAveragesModel(
      avgXp: (json['avg_xp'] as num?)?.toDouble() ?? 0,
      avgStreak: (json['avg_streak'] as num?)?.toDouble() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      avgReadingTime: (json['avg_reading_time'] as num?)?.toDouble() ?? 0,
      avgBooksRead: (json['avg_books_read'] as num?)?.toDouble() ?? 0,
    );
  }

  final double avgXp;
  final double avgStreak;
  final double avgProgress;
  final double avgReadingTime;
  final double avgBooksRead;

  GlobalAverages toEntity() => GlobalAverages(
        avgXp: avgXp,
        avgStreak: avgStreak,
        avgProgress: avgProgress,
        avgReadingTime: avgReadingTime,
        avgBooksRead: avgBooksRead,
      );
}
