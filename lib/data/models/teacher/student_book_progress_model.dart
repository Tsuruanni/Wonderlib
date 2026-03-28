import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentBookProgress - handles JSON serialization
class StudentBookProgressModel {

  const StudentBookProgressModel({
    required this.bookId,
    required this.bookTitle,
    this.bookCoverUrl,
    required this.completionPercentage,
    required this.totalReadingTime,
    required this.completedChapters,
    required this.totalChapters,
    this.lastReadAt,
  });

  factory StudentBookProgressModel.fromJson(Map<String, dynamic> json) {
    return StudentBookProgressModel(
      bookId: json['book_id'] as String,
      bookTitle: json['book_title'] as String,
      bookCoverUrl: json['book_cover_url'] as String?,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0,
      totalReadingTime: (json['total_reading_time'] as num?)?.toInt() ?? 0,
      completedChapters: (json['completed_chapters'] as num?)?.toInt() ?? 0,
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
    );
  }

  final String bookId;
  final String bookTitle;
  final String? bookCoverUrl;
  final double completionPercentage;
  final int totalReadingTime;
  final int completedChapters;
  final int totalChapters;
  final DateTime? lastReadAt;

  StudentBookProgress toEntity() {
    return StudentBookProgress(
      bookId: bookId,
      bookTitle: bookTitle,
      bookCoverUrl: bookCoverUrl,
      completionPercentage: completionPercentage,
      totalReadingTime: totalReadingTime,
      completedChapters: completedChapters,
      totalChapters: totalChapters,
      lastReadAt: lastReadAt,
    );
  }
}
