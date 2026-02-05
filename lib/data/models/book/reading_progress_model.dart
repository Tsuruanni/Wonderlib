import '../../../domain/entities/reading_progress.dart';

/// Data model for ReadingProgress - handles JSON serialization
class ReadingProgressModel {

  const ReadingProgressModel({
    required this.id,
    required this.userId,
    required this.bookId,
    this.chapterId,
    this.currentPage = 1,
    this.isCompleted = false,
    this.completionPercentage = 0,
    this.totalReadingTime = 0,
    this.completedChapterIds = const [],
    required this.startedAt,
    this.completedAt,
    required this.updatedAt,
  });

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) {
    final completedChapterIdsJson = json['completed_chapter_ids'] as List<dynamic>?;
    final completedChapterIds =
        completedChapterIdsJson?.map((id) => id as String).toList() ?? [];

    return ReadingProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      chapterId: json['chapter_id'] as String?,
      currentPage: json['current_page'] as int? ?? 1,
      isCompleted: json['is_completed'] as bool? ?? false,
      completionPercentage:
          (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      totalReadingTime: json['total_reading_time'] as int? ?? 0,
      completedChapterIds: completedChapterIds,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory ReadingProgressModel.fromEntity(ReadingProgress entity) {
    return ReadingProgressModel(
      id: entity.id,
      userId: entity.userId,
      bookId: entity.bookId,
      chapterId: entity.chapterId,
      currentPage: entity.currentPage,
      isCompleted: entity.isCompleted,
      completionPercentage: entity.completionPercentage,
      totalReadingTime: entity.totalReadingTime,
      completedChapterIds: entity.completedChapterIds,
      startedAt: entity.startedAt,
      completedAt: entity.completedAt,
      updatedAt: entity.updatedAt,
    );
  }
  final String id;
  final String userId;
  final String bookId;
  final String? chapterId;
  final int currentPage;
  final bool isCompleted;
  final double completionPercentage;
  final int totalReadingTime;
  final List<String> completedChapterIds;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'current_page': currentPage,
      'is_completed': isCompleted,
      'completion_percentage': completionPercentage,
      'total_reading_time': totalReadingTime,
      'completed_chapter_ids': completedChapterIds,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReadingProgress toEntity() {
    return ReadingProgress(
      id: id,
      userId: userId,
      bookId: bookId,
      chapterId: chapterId,
      currentPage: currentPage,
      isCompleted: isCompleted,
      completionPercentage: completionPercentage,
      totalReadingTime: totalReadingTime,
      completedChapterIds: completedChapterIds,
      startedAt: startedAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }
}
