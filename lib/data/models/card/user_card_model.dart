import '../../../domain/entities/card.dart';
import 'myth_card_model.dart';

class UserCardModel {
  const UserCardModel({
    required this.id,
    required this.userId,
    required this.cardId,
    this.cardData,
    required this.quantity,
    required this.firstObtainedAt,
  });

  /// Parse from Supabase join query: user_cards.select('*, myth_cards(*)')
  factory UserCardModel.fromJson(Map<String, dynamic> json) {
    return UserCardModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cardId: json['card_id'] as String,
      cardData: json['myth_cards'] as Map<String, dynamic>?,
      quantity: json['quantity'] as int? ?? 1,
      firstObtainedAt: DateTime.parse(json['first_obtained_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String cardId;
  final Map<String, dynamic>? cardData;
  final int quantity;
  final DateTime firstObtainedAt;

  UserCard toEntity() {
    final card = cardData != null
        ? MythCardModel.fromJson(cardData!).toEntity()
        : MythCard(
            id: cardId,
            cardNo: '',
            name: 'Unknown',
            category: CardCategory.turkishMyths,
            rarity: CardRarity.common,
            power: 0,
            createdAt: firstObtainedAt,
          );

    return UserCard(
      id: id,
      userId: userId,
      cardId: cardId,
      card: card,
      quantity: quantity,
      firstObtainedAt: firstObtainedAt,
    );
  }
}
