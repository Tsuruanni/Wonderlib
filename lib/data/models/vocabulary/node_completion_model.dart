import '../../../domain/entities/vocabulary.dart';

class NodeCompletionModel {
  const NodeCompletionModel({
    required this.unitId,
    required this.nodeType,
    required this.completedAt,
    this.itemId,
  });

  final String unitId;
  final String nodeType;
  final DateTime completedAt;
  final String? itemId;

  factory NodeCompletionModel.fromJson(Map<String, dynamic> json) {
    return NodeCompletionModel(
      unitId: json['unit_id'] as String,
      nodeType: json['node_type'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      itemId: json['item_id'] as String?,
    );
  }

  NodeCompletion toEntity() => NodeCompletion(
        unitId: unitId,
        nodeType: nodeType,
        completedAt: completedAt,
        itemId: itemId,
      );
}
