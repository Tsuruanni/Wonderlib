import '../../../domain/repositories/teacher_repository.dart';

/// Model for BookReadingStats - handles JSON serialization
class BookReadingStatsModel {
  const BookReadingStatsModel({
    required this.bookId,
    required this.title,
    this.coverUrl,
    required this.level,
    required this.totalReaders,
    required this.completedReaders,
    required this.avgProgress,
  });

  factory BookReadingStatsModel.fromJson(Map<String, dynamic> json) {
    return BookReadingStatsModel(
      bookId: json['book_id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      level: json['level'] as String? ?? '',
      totalReaders: (json['total_readers'] as num?)?.toInt() ?? 0,
      completedReaders: (json['completed_readers'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
    );
  }

  final String bookId;
  final String title;
  final String? coverUrl;
  final String level;
  final int totalReaders;
  final int completedReaders;
  final double avgProgress;

  BookReadingStats toEntity() {
    return BookReadingStats(
      bookId: bookId,
      title: title,
      coverUrl: coverUrl,
      level: level,
      totalReaders: totalReaders,
      completedReaders: completedReaders,
      avgProgress: avgProgress,
    );
  }
}
