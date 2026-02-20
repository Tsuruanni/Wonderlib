import '../../../domain/entities/card.dart';

class BuyPackResultModel {
  const BuyPackResultModel({
    required this.coinsSpent,
    required this.coinsRemaining,
    required this.unopenedPacks,
  });

  factory BuyPackResultModel.fromJson(Map<String, dynamic> json) {
    return BuyPackResultModel(
      coinsSpent: (json['coins_spent'] as num?)?.toInt() ?? 0,
      coinsRemaining: (json['coins_remaining'] as num?)?.toInt() ?? 0,
      unopenedPacks: (json['unopened_packs'] as num?)?.toInt() ?? 0,
    );
  }

  final int coinsSpent;
  final int coinsRemaining;
  final int unopenedPacks;

  Map<String, dynamic> toJson() => {
    'coins_spent': coinsSpent,
    'coins_remaining': coinsRemaining,
    'unopened_packs': unopenedPacks,
  };

  BuyPackResult toEntity() {
    return BuyPackResult(
      coinsSpent: coinsSpent,
      coinsRemaining: coinsRemaining,
      unopenedPacks: unopenedPacks,
    );
  }
}
