import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// A unit from the class's learning path, shown to teacher during assignment creation
class ClassLearningPathUnit extends Equatable {
  const ClassLearningPathUnit({
    required this.pathId,
    required this.pathName,
    required this.unitId,
    required this.scopeLpUnitId,
    required this.unitName,
    required this.unitColor,
    required this.unitIcon,
    required this.unitSortOrder,
    required this.items,
  });

  final String pathId;
  final String pathName;
  final String unitId;
  final String scopeLpUnitId;
  final String unitName;
  final String unitColor;
  final String unitIcon;
  final int unitSortOrder;
  final List<ClassLearningPathItem> items;

  /// Count of items that are tracked for progress (word_list + book only)
  int get trackableItemCount =>
      items.where((i) => i.itemType == LearningPathItemType.wordList || i.itemType == LearningPathItemType.book).length;

  @override
  List<Object?> get props => [
    pathId, pathName, unitId, scopeLpUnitId, unitName,
    unitColor, unitIcon, unitSortOrder, items,
  ];
}

class ClassLearningPathItem extends Equatable {
  const ClassLearningPathItem({
    required this.itemType,
    required this.sortOrder,
    this.wordListId,
    this.wordListName,
    this.words,
    this.bookId,
    this.bookTitle,
    this.bookChapterCount,
  });

  final LearningPathItemType itemType;
  final int sortOrder;
  final String? wordListId;
  final String? wordListName;
  final List<String>? words;
  final String? bookId;
  final String? bookTitle;
  final int? bookChapterCount;

  @override
  List<Object?> get props => [
    itemType, sortOrder, wordListId, wordListName, words,
    bookId, bookTitle, bookChapterCount,
  ];
}
