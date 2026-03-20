import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

class LearningPathItem extends Equatable {
  const LearningPathItem({
    required this.itemType,
    required this.itemId,
    required this.sortOrder,
  });

  final LearningPathItemType itemType;
  final String itemId;
  final int sortOrder;

  @override
  List<Object?> get props => [itemType, itemId, sortOrder];
}
