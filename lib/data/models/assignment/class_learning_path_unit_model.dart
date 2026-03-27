import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/class_learning_path_unit.dart';

class ClassLearningPathUnitModel {
  /// Build entity list from flat RPC rows (same pattern as LearningPathModel)
  static List<ClassLearningPathUnit> fromRpcRows(List<dynamic> rows) {
    final Map<String, _UnitBuilder> unitBuilders = {};

    for (final row in rows) {
      final scopeLpUnitId = row['scope_lp_unit_id'] as String;

      unitBuilders.putIfAbsent(scopeLpUnitId, () => _UnitBuilder(
        pathId: row['path_id'] as String,
        pathName: row['path_name'] as String,
        unitId: row['unit_id'] as String,
        scopeLpUnitId: scopeLpUnitId,
        unitName: row['unit_name'] as String,
        unitColor: row['unit_color'] as String? ?? '#6366F1',
        unitIcon: row['unit_icon'] as String? ?? '📚',
        unitSortOrder: (row['unit_sort_order'] as num).toInt(),
      ));

      // Add item if present (item columns may be null for units with no items)
      if (row['item_type'] != null) {
        final wordsRaw = row['words'];
        List<String>? words;
        if (wordsRaw is List) {
          words = wordsRaw.map((e) => e.toString()).toList();
        }

        unitBuilders[scopeLpUnitId]!.items.add(ClassLearningPathItem(
          itemType: LearningPathItemType.fromDbValue(row['item_type'] as String),
          sortOrder: (row['item_sort_order'] as num).toInt(),
          wordListId: row['word_list_id'] as String?,
          wordListName: row['word_list_name'] as String?,
          words: words,
          bookId: row['book_id'] as String?,
          bookTitle: row['book_title'] as String?,
          bookChapterCount: (row['book_chapter_count'] as num?)?.toInt(),
        ));
      }
    }

    final units = unitBuilders.values.map((b) => b.build()).toList();
    units.sort((a, b) => a.unitSortOrder.compareTo(b.unitSortOrder));
    return units;
  }
}

class _UnitBuilder {
  _UnitBuilder({
    required this.pathId,
    required this.pathName,
    required this.unitId,
    required this.scopeLpUnitId,
    required this.unitName,
    required this.unitColor,
    required this.unitIcon,
    required this.unitSortOrder,
  });

  final String pathId;
  final String pathName;
  final String unitId;
  final String scopeLpUnitId;
  final String unitName;
  final String unitColor;
  final String unitIcon;
  final int unitSortOrder;
  final List<ClassLearningPathItem> items = [];

  ClassLearningPathUnit build() {
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ClassLearningPathUnit(
      pathId: pathId,
      pathName: pathName,
      unitId: unitId,
      scopeLpUnitId: scopeLpUnitId,
      unitName: unitName,
      unitColor: unitColor,
      unitIcon: unitIcon,
      unitSortOrder: unitSortOrder,
      items: items,
    );
  }
}
