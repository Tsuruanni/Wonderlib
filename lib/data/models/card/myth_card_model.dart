import '../../../domain/entities/card.dart';

class MythCardModel {
  const MythCardModel({
    required this.id,
    required this.cardNo,
    required this.name,
    required this.category,
    required this.rarity,
    required this.power,
    this.specialSkill,
    this.description,
    this.categoryIcon,
    this.isActive = true,
    this.imageUrl, // Added field
    required this.createdAt,
  });

  factory MythCardModel.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['image_url'] as String? ??
        cardAssetPath(json['name'] as String);

    return MythCardModel(
      id: json['id'] as String,
      cardNo: json['card_no'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      rarity: json['rarity'] as String,
      power: (json['power'] as num?)?.toInt() ?? 0,
      specialSkill: json['special_skill'] as String?,
      description: json['description'] as String?,
      categoryIcon: json['category_icon'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: imageUrl,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Generates an asset path from a card name by stripping special characters.
  /// e.g. "Pandora's Box" → "assets/images/cards/Pandoras Box.png"
  static String cardAssetPath(String name) {
    final sanitized = name
        .replaceAll("'", '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    return 'assets/images/cards/$sanitized.png';
  }

  factory MythCardModel.fromEntity(MythCard entity) {
    return MythCardModel(
      id: entity.id,
      cardNo: entity.cardNo,
      name: entity.name,
      category: entity.category.dbValue,
      rarity: rarityToString(entity.rarity),
      power: entity.power,
      specialSkill: entity.specialSkill,
      description: entity.description,
      categoryIcon: entity.categoryIcon,
      isActive: entity.isActive,
      imageUrl: entity.imageUrl,
      createdAt: entity.createdAt,
    );
  }

  final String id;
  final String cardNo;
  final String name;
  final String category;
  final String rarity;
  final int power;
  final String? specialSkill;
  final String? description;
  final String? categoryIcon;
  final bool isActive;
  final String? imageUrl; // Added field
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'card_no': cardNo,
      'name': name,
      'category': category,
      'rarity': rarity,
      'power': power,
      'special_skill': specialSkill,
      'description': description,
      'category_icon': categoryIcon,
      'is_active': isActive,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MythCard toEntity() {
    return MythCard(
      id: id,
      cardNo: cardNo,
      name: name,
      category: CardCategory.fromDbValue(category),
      rarity: parseRarity(rarity),
      power: power,
      specialSkill: specialSkill,
      description: description,
      categoryIcon: categoryIcon,
      isActive: isActive,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }

  static CardRarity parseRarity(String rarity) {
    switch (rarity) {
      case 'common':
        return CardRarity.common;
      case 'rare':
        return CardRarity.rare;
      case 'epic':
        return CardRarity.epic;
      case 'legendary':
        return CardRarity.legendary;
      default:
        return CardRarity.common;
    }
  }

  static String rarityToString(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 'common';
      case CardRarity.rare:
        return 'rare';
      case CardRarity.epic:
        return 'epic';
      case CardRarity.legendary:
        return 'legendary';
    }
  }
}
