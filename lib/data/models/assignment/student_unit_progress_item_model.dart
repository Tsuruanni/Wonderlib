import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/student_unit_progress_item.dart';

class StudentUnitProgressItemModel {
  static StudentUnitProgressItem fromJson(Map<String, dynamic> json) {
    return StudentUnitProgressItem(
      itemType: LearningPathItemType.fromDbValue(json['out_item_type'] as String),
      sortOrder: (json['out_sort_order'] as num).toInt(),
      wordListId: json['out_word_list_id'] as String?,
      wordListName: json['out_word_list_name'] as String?,
      wordCount: (json['out_word_count'] as num?)?.toInt(),
      isWordListCompleted: json['out_is_word_list_completed'] as bool?,
      bestScore: (json['out_best_score'] as num?)?.toDouble(),
      bestAccuracy: (json['out_best_accuracy'] as num?)?.toDouble(),
      totalSessions: (json['out_total_sessions'] as num?)?.toInt(),
      bookId: json['out_book_id'] as String?,
      bookTitle: json['out_book_title'] as String?,
      totalChapters: (json['out_total_chapters'] as num?)?.toInt(),
      completedChapters: (json['out_completed_chapters'] as num?)?.toInt(),
      isBookCompleted: json['out_is_book_completed'] as bool?,
    );
  }
}
