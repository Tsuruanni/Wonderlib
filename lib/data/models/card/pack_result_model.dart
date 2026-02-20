import '../../../domain/entities/card.dart';
import 'myth_card_model.dart';

class PackResultModel {
  const PackResultModel({
    required this.cards,
    required this.packGlowRarity,
    this.packsRemaining = 0,
    this.pityTriggered = false,
  });

  /// Parse the JSONB returned by open_card_pack() RPC function
  factory PackResultModel.fromJson(Map<String, dynamic> json) {
    final cardsJson = json['cards'] as List<dynamic>? ?? [];
    final cards = cardsJson.map((c) {
      final cardJson = c as Map<String, dynamic>;
      final name = cardJson['name'] as String? ?? '';
      final imageUrl = cardJson['image_url'] as String? ??
          MythCardModel.cardAssetPath(name);

      return PackCardModel(
        id: cardJson['id'] as String? ?? '',
        cardNo: cardJson['card_no'] as String? ?? '',
        name: name,
        category: cardJson['category'] as String? ?? '',
        categoryIcon: cardJson['category_icon'] as String?,
        rarity: cardJson['rarity'] as String? ?? 'common',
        power: (cardJson['power'] as num?)?.toInt() ?? 0,
        specialSkill: cardJson['special_skill'] as String?,
        description: cardJson['description'] as String?,
        isNew: cardJson['is_new'] as bool? ?? true,
        quantity: (cardJson['quantity'] as num?)?.toInt() ?? 1,
        imageUrl: imageUrl,
      );
    }).toList();

    return PackResultModel(
      cards: cards,
      packGlowRarity: json['pack_glow_rarity'] as String,
      packsRemaining: json['packs_remaining'] as int? ?? 0,
      pityTriggered: json['pity_triggered'] as bool? ?? false,
    );
  }

  final List<PackCardModel> cards;
  final String packGlowRarity;
  final int packsRemaining;
  final bool pityTriggered;

  PackResult toEntity() {
    return PackResult(
      cards: cards.map((c) => c.toEntity()).toList(),
      packGlowRarity: MythCardModel.parseRarity(packGlowRarity),
      packsRemaining: packsRemaining,
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
  final int quantity;
  final String? imageUrl;

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
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );

    return PackCard(
      card: card,
      isNew: isNew,
      currentQuantity: quantity,
    );
  }
}
