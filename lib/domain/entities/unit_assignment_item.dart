import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// A single item within a unit assignment, with student completion state
class UnitAssignmentItem extends Equatable {
  const UnitAssignmentItem({
    required this.itemType,
    required this.sortOrder,
    this.wordListId,
    this.wordListName,
    this.wordCount,
    this.isWordListCompleted,
    this.bookId,
    this.bookTitle,
    this.totalChapters,
    this.completedChapters,
    this.isBookCompleted,
  });

  final LearningPathItemType itemType;
  final int sortOrder;
  // Word list fields
  final String? wordListId;
  final String? wordListName;
  final int? wordCount;
  final bool? isWordListCompleted;
  // Book fields
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
    isWordListCompleted, bookId, bookTitle, totalChapters,
    completedChapters, isBookCompleted,
  ];
}
