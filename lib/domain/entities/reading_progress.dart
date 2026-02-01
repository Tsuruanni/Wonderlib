import 'package:equatable/equatable.dart';

class ReadingProgress extends Equatable {

  const ReadingProgress({
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
  final String id;
  final String userId;
  final String bookId;
  final String? chapterId;
  final int currentPage;
  final bool isCompleted;
  final double completionPercentage;
  final int totalReadingTime; // in seconds
  final List<String> completedChapterIds; // chapters user has completed
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  String get formattedReadingTime {
    if (totalReadingTime < 60) return '${totalReadingTime}s';
    if (totalReadingTime < 3600) return '${totalReadingTime ~/ 60}m';
    final hours = totalReadingTime ~/ 3600;
    final mins = (totalReadingTime % 3600) ~/ 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  ReadingProgress copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? chapterId,
    int? currentPage,
    bool? isCompleted,
    double? completionPercentage,
    int? totalReadingTime,
    List<String>? completedChapterIds,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      currentPage: currentPage ?? this.currentPage,
      isCompleted: isCompleted ?? this.isCompleted,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
      completedChapterIds: completedChapterIds ?? this.completedChapterIds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        bookId,
        chapterId,
        currentPage,
        isCompleted,
        completionPercentage,
        totalReadingTime,
        completedChapterIds,
        startedAt,
        completedAt,
        updatedAt,
      ];
}
