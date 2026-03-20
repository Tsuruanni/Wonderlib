import 'package:equatable/equatable.dart';
import 'learning_path_item.dart';

class LearningPath extends Equatable {
  const LearningPath({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.units,
    this.sequentialLock = true,
    this.booksExemptFromLock = true,
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<LearningPathUnit> units;
  final bool sequentialLock;
  final bool booksExemptFromLock;

  @override
  List<Object?> get props => [id, name, sortOrder, units, sequentialLock, booksExemptFromLock];
}

class LearningPathUnit extends Equatable {
  const LearningPathUnit({
    required this.unitId,
    required this.unitName,
    this.unitColor,
    this.unitIcon,
    required this.sortOrder,
    required this.items,
  });

  final String unitId;
  final String unitName;
  final String? unitColor;
  final String? unitIcon;
  final int sortOrder;
  final List<LearningPathItem> items;

  @override
  List<Object?> get props => [unitId, unitName, unitColor, unitIcon, sortOrder, items];
}
