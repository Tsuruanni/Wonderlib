import '../../../domain/entities/card.dart';
import '../../../domain/entities/treasure_wheel.dart';
import '../card/myth_card_model.dart';

class TreasureSpinResultModel {
  const TreasureSpinResultModel({
    required this.sliceIndex,
    required this.sliceLabel,
    required this.rewardType,
    required this.rewardAmount,
    this.cards,
  });

  factory TreasureSpinResultModel.fromJson(Map<String, dynamic> json) {
    List<PackCard>? cards;
    final cardsJson = json['cards'];
    if (cardsJson != null && cardsJson is List && cardsJson.isNotEmpty) {
      cards = cardsJson.map((c) {
        final cardJson = c as Map<String, dynamic>;
        return PackCard(
          card: MythCardModel.fromJson({
            'id': cardJson['id'],
            'card_no': cardJson['card_no'] ?? '',
            'name': cardJson['name'] ?? '',
            'category': cardJson['category'] ?? '',
            'rarity': cardJson['rarity'] ?? 'common',
            'power': cardJson['power'] ?? 0,
            'special_skill': cardJson['special_skill'],
            'description': cardJson['description'],
            'category_icon': cardJson['category_icon'],
            'is_active': true,
            'image_url': cardJson['image_url'],
            'created_at': cardJson['created_at'] ?? DateTime.now().toIso8601String(),
          }).toEntity(),
          isNew: cardJson['is_new'] as bool? ?? false,
          currentQuantity: (cardJson['quantity'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    }

    return TreasureSpinResultModel(
      sliceIndex: (json['slice_index'] as num).toInt(),
      sliceLabel: json['slice_label'] as String,
      rewardType: json['reward_type'] as String,
      rewardAmount: (json['reward_amount'] as num).toInt(),
      cards: cards,
    );
  }

  final int sliceIndex;
  final String sliceLabel;
  final String rewardType;
  final int rewardAmount;
  final List<PackCard>? cards;

  TreasureSpinResult toEntity() {
    return TreasureSpinResult(
      sliceIndex: sliceIndex,
      sliceLabel: sliceLabel,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      cards: cards,
    );
  }
}
