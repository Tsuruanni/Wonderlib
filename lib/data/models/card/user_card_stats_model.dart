import '../../../domain/entities/card.dart';

class UserCardStatsModel {
  const UserCardStatsModel({
    required this.userId,
    this.packsSinceLegendary = 0,
    this.totalPacksOpened = 0,
    this.totalUniqueCards = 0,
  });

  factory UserCardStatsModel.fromJson(Map<String, dynamic> json) {
    return UserCardStatsModel(
      userId: json['user_id'] as String,
      packsSinceLegendary: json['packs_since_legendary'] as int? ?? 0,
      totalPacksOpened: json['total_packs_opened'] as int? ?? 0,
      totalUniqueCards: json['total_unique_cards'] as int? ?? 0,
    );
  }

  final String userId;
  final int packsSinceLegendary;
  final int totalPacksOpened;
  final int totalUniqueCards;

  UserCardStats toEntity() {
    return UserCardStats(
      userId: userId,
      packsSinceLegendary: packsSinceLegendary,
      totalPacksOpened: totalPacksOpened,
      totalUniqueCards: totalUniqueCards,
    );
  }
}
