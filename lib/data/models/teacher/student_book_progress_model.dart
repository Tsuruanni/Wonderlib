import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentBookProgress - handles JSON serialization
class StudentBookProgressModel {
  final String bookId;
  final String bookTitle;
  final String? bookCoverUrl;
  final double completionPercentage;
  final int totalReadingTime;
  final int completedChapters;
  final int totalChapters;
  final DateTime? lastReadAt;

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

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'book_title': bookTitle,
      'book_cover_url': bookCoverUrl,
      'completion_percentage': completionPercentage,
      'total_reading_time': totalReadingTime,
      'completed_chapters': completedChapters,
      'total_chapters': totalChapters,
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }

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

  factory StudentBookProgressModel.fromEntity(StudentBookProgress entity) {
    return StudentBookProgressModel(
      bookId: entity.bookId,
      bookTitle: entity.bookTitle,
      bookCoverUrl: entity.bookCoverUrl,
      completionPercentage: entity.completionPercentage,
      totalReadingTime: entity.totalReadingTime,
      completedChapters: entity.completedChapters,
      totalChapters: entity.totalChapters,
      lastReadAt: entity.lastReadAt,
    );
  }
}
