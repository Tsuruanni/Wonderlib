import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// Per-item progress for a student in a unit assignment (teacher view)
class StudentUnitProgressItem extends Equatable {
  const StudentUnitProgressItem({
    required this.itemType,
    required this.sortOrder,
    this.wordListId,
    this.wordListName,
    this.wordCount,
    this.isWordListCompleted,
    this.bestScore,
    this.bestAccuracy,
    this.totalSessions,
    this.bookId,
    this.bookTitle,
    this.totalChapters,
    this.completedChapters,
    this.isBookCompleted,
  });

  final LearningPathItemType itemType;
  final int sortOrder;
  final String? wordListId;
  final String? wordListName;
  final int? wordCount;
  final bool? isWordListCompleted;
  final double? bestScore;
  final double? bestAccuracy;
  final int? totalSessions;
  final String? bookId;
  final String? bookTitle;
  final int? totalChapters;
  final int? completedChapters;
  final bool? isBookCompleted;

  bool get isTracked => itemType == LearningPathItemType.wordList || itemType == LearningPathItemType.book;

  bool get isCompleted {
    if (itemType == LearningPathItemType.wordList) return isWordListCompleted ?? false;
    if (itemType == LearningPathItemType.book) return isBookCompleted ?? false;
    return false;
  }

  @override
  List<Object?> get props => [
    itemType, sortOrder, wordListId, wordListName, wordCount,
    isWordListCompleted, bestScore, bestAccuracy, totalSessions,
    bookId, bookTitle, totalChapters, completedChapters, isBookCompleted,
  ];
}
