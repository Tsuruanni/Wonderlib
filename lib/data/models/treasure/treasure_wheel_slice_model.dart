import '../../../domain/entities/treasure_wheel.dart';

class TreasureWheelSliceModel {
  const TreasureWheelSliceModel({
    required this.id,
    required this.label,
    required this.rewardType,
    required this.rewardAmount,
    required this.weight,
    required this.color,
    required this.sortOrder,
  });

  factory TreasureWheelSliceModel.fromJson(Map<String, dynamic> json) {
    return TreasureWheelSliceModel(
      id: json['id'] as String,
      label: json['label'] as String,
      rewardType: json['reward_type'] as String,
      rewardAmount: (json['reward_amount'] as num).toInt(),
      weight: (json['weight'] as num).toInt(),
      color: json['color'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
    );
  }

  final String id;
  final String label;
  final String rewardType;
  final int rewardAmount;
  final int weight;
  final String color;
  final int sortOrder;

  TreasureWheelSlice toEntity() {
    return TreasureWheelSlice(
      id: id,
      label: label,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      weight: weight,
      color: color,
      sortOrder: sortOrder,
    );
  }
}
