import '../../../domain/entities/treasure_wheel.dart';

class TreasureSpinResultModel {
  const TreasureSpinResultModel({
    required this.sliceIndex,
    required this.sliceLabel,
    required this.rewardType,
    required this.rewardAmount,
  });

  factory TreasureSpinResultModel.fromJson(Map<String, dynamic> json) {
    return TreasureSpinResultModel(
      sliceIndex: (json['slice_index'] as num).toInt(),
      sliceLabel: json['slice_label'] as String,
      rewardType: json['reward_type'] as String,
      rewardAmount: (json['reward_amount'] as num).toInt(),
    );
  }

  final int sliceIndex;
  final String sliceLabel;
  final String rewardType;
  final int rewardAmount;

  TreasureSpinResult toEntity() {
    return TreasureSpinResult(
      sliceIndex: sliceIndex,
      sliceLabel: sliceLabel,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
    );
  }
}
