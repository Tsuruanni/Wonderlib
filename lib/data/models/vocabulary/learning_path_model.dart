import 'package:owlio_shared/owlio_shared.dart';
import '../../../domain/entities/learning_path.dart';
import '../../../domain/entities/learning_path_item.dart';

class LearningPathModel {
  /// Parses flat RPC rows into hierarchical LearningPath list
  static List<LearningPath> fromRpcRows(List<Map<String, dynamic>> rows) {
    final pathMap = <String, _PathBuilder>{};

    for (final row in rows) {
      final lpId = row['learning_path_id'] as String;
      final pathBuilder = pathMap.putIfAbsent(
        lpId,
        () => _PathBuilder(
          id: lpId,
          name: row['learning_path_name'] as String,
          sortOrder: row['lp_sort_order'] as int,
          sequentialLock: row['sequential_lock'] as bool? ?? true,
          booksExemptFromLock: row['books_exempt_from_lock'] as bool? ?? true,
          unitGate: row['unit_gate'] as bool? ?? true,
        ),
      );

      final unitId = row['unit_id'] as String;
      final unitBuilder = pathBuilder.units.putIfAbsent(
        unitId,
        () => _UnitBuilder(
          unitId: unitId,
          unitName: row['unit_name'] as String,
          unitColor: row['unit_color'] as String?,
          unitIcon: row['unit_icon'] as String?,
          sortOrder: row['unit_sort_order'] as int,
          tileThemeId: row['tile_theme_id'] as String?,
        ),
      );

      final itemType = row['item_type'] as String?;
      final itemId = row['item_id'] as String?;
      if (itemType != null && itemId != null) {
        unitBuilder.items.add(
          LearningPathItem(
            itemType: LearningPathItemType.fromDbValue(itemType),
            itemId: itemId,
            sortOrder: row['item_sort_order'] as int? ?? 0,
          ),
        );
      }
    }

    return pathMap.values
        .map(
          (pb) => LearningPath(
            id: pb.id,
            name: pb.name,
            sortOrder: pb.sortOrder,
            sequentialLock: pb.sequentialLock,
            booksExemptFromLock: pb.booksExemptFromLock,
            unitGate: pb.unitGate,
            units: pb.units.values
                .map(
                  (ub) => LearningPathUnit(
                    unitId: ub.unitId,
                    unitName: ub.unitName,
                    unitColor: ub.unitColor,
                    unitIcon: ub.unitIcon,
                    sortOrder: ub.sortOrder,
                    tileThemeId: ub.tileThemeId,
                    items: ub.items..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
                  ),
                )
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}

class _PathBuilder {
  _PathBuilder({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.sequentialLock,
    required this.booksExemptFromLock,
    required this.unitGate,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool sequentialLock;
  final bool booksExemptFromLock;
  final bool unitGate;
  final Map<String, _UnitBuilder> units = {};
}

class _UnitBuilder {
  _UnitBuilder({
    required this.unitId,
    required this.unitName,
    this.unitColor,
    this.unitIcon,
    required this.sortOrder,
    this.tileThemeId,
  });

  final String unitId;
  final String unitName;
  final String? unitColor;
  final String? unitIcon;
  final int sortOrder;
  final String? tileThemeId;
  final List<LearningPathItem> items = [];
}
