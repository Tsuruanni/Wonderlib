import '../../../domain/entities/unit_assignment_item.dart';

class UnitAssignmentItemModel {
  static UnitAssignmentItem fromJson(Map<String, dynamic> json) {
    return UnitAssignmentItem(
      itemType: json['item_type'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
      wordListId: json['word_list_id'] as String?,
      wordListName: json['word_list_name'] as String?,
      wordCount: (json['word_count'] as num?)?.toInt(),
      isWordListCompleted: json['is_word_list_completed'] as bool?,
      bookId: json['book_id'] as String?,
      bookTitle: json['book_title'] as String?,
      totalChapters: (json['total_chapters'] as num?)?.toInt(),
      completedChapters: (json['completed_chapters'] as num?)?.toInt(),
      isBookCompleted: json['is_book_completed'] as bool?,
    );
  }
}
