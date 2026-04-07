import 'package:equatable/equatable.dart';

/// A single slice on the treasure wheel (from admin config)
class TreasureWheelSlice extends Equatable {
  const TreasureWheelSlice({
    required this.id,
    required this.label,
    required this.rewardType,
    required this.rewardAmount,
    required this.weight,
    required this.color,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String rewardType; // 'coin' or 'card_pack'
  final int rewardAmount;
  final int weight;
  final String color; // hex color
  final int sortOrder;

  @override
  List<Object?> get props => [id, label, rewardType, rewardAmount, weight, color, sortOrder];
}

/// Result of spinning the treasure wheel
class TreasureSpinResult extends Equatable {
  const TreasureSpinResult({
    required this.sliceIndex,
    required this.sliceLabel,
    required this.rewardType,
    required this.rewardAmount,
  });

  final int sliceIndex;
  final String sliceLabel;
  final String rewardType;
  final int rewardAmount;

  @override
  List<Object?> get props => [sliceIndex, sliceLabel, rewardType, rewardAmount];
}
