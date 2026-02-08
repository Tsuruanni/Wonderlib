import '../../../domain/entities/card.dart';
import 'myth_card_model.dart';

class PackResultModel {
  const PackResultModel({
    required this.cards,
    required this.packGlowRarity,
    required this.coinsSpent,
    required this.coinsRemaining,
    this.pityTriggered = false,
  });

  /// Parse the JSONB returned by open_card_pack() RPC function
  factory PackResultModel.fromJson(Map<String, dynamic> json) {
    final cardsJson = json['cards'] as List<dynamic>;
    final cards = cardsJson.map((c) {
      final cardJson = c as Map<String, dynamic>;
      // Mock image logic
      String? mockImage;
      if (cardJson['image_url'] == null) {
        final hash = (cardJson['name'] as String).hashCode;
        mockImage = 'https://picsum.photos/seed/$hash/400/560';
      }

      return PackCardModel(
        id: cardJson['id'] as String,
        cardNo: cardJson['card_no'] as String,
        name: cardJson['name'] as String,
        category: cardJson['category'] as String,
        categoryIcon: cardJson['category_icon'] as String?,
        rarity: cardJson['rarity'] as String,
        power: cardJson['power'] as int,
        specialSkill: cardJson['special_skill'] as String?,
        description: cardJson['description'] as String?,
        isNew: cardJson['is_new'] as bool,
        quantity: cardJson['quantity'] as int,
        imageUrl: cardJson['image_url'] as String? ?? mockImage,
      );
    }).toList();

    return PackResultModel(
      cards: cards,
      packGlowRarity: json['pack_glow_rarity'] as String,
      coinsSpent: json['coins_spent'] as int,
      coinsRemaining: json['coins_remaining'] as int,
      pityTriggered: json['pity_triggered'] as bool? ?? false,
    );
  }

  final List<PackCardModel> cards;
  final String packGlowRarity;
  final int coinsSpent;
  final int coinsRemaining;
  final bool pityTriggered;

  PackResult toEntity() {
    return PackResult(
      cards: cards.map((c) => c.toEntity()).toList(),
      packGlowRarity: MythCardModel.parseRarity(packGlowRarity),
      coinsSpent: coinsSpent,
      coinsRemaining: coinsRemaining,
      pityTriggered: pityTriggered,
    );
  }
}

class PackCardModel {
  const PackCardModel({
    required this.id,
    required this.cardNo,
    required this.name,
    required this.category,
    this.categoryIcon,
    required this.rarity,
    required this.power,
    this.specialSkill,
    this.description,
    required this.isNew,
    required this.quantity,
    this.imageUrl,
  });

  final String id;
  final String cardNo;
  final String name;
  final String category;
  final String? categoryIcon;
  final String rarity;
  final int power;
  final String? specialSkill;
  final String? description;
  final bool isNew;
  final int quantity; // Restored field
  final String? imageUrl; // Added field

  PackCard toEntity() {
    final card = MythCard(
      id: id,
      cardNo: cardNo,
      name: name,
      category: CardCategory.fromDbValue(category),
      rarity: MythCardModel.parseRarity(rarity),
      power: power,
      specialSkill: specialSkill,
      description: description,
      categoryIcon: categoryIcon,
      imageUrl: imageUrl, // Added field
      createdAt: DateTime.now(),
    );

    return PackCard(
      card: card,
      isNew: isNew,
      currentQuantity: quantity,
    );
  }
}
