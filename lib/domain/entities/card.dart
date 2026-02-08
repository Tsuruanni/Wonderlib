import 'package:equatable/equatable.dart';

/// Card rarity levels - determines drop rate, visual style, and value
enum CardRarity {
  common,
  rare,
  epic,
  legendary;

  /// Display label for UI
  String get label {
    switch (this) {
      case common:
        return 'Common';
      case rare:
        return 'Rare';
      case epic:
        return 'Epic';
      case legendary:
        return 'Legendary';
    }
  }
}

/// Mythology categories - 8 total, 12 cards each
enum CardCategory {
  turkishMyths,
  ancientGreece,
  vikingIceLands,
  egyptianDeserts,
  farEast,
  medievalMagic,
  legendaryWeapons,
  darkCreatures;

  /// Display label for UI
  String get label {
    switch (this) {
      case turkishMyths:
        return 'Turkish Myths';
      case ancientGreece:
        return 'Ancient Greece';
      case vikingIceLands:
        return 'Viking Ice Lands';
      case egyptianDeserts:
        return 'Egyptian Deserts';
      case farEast:
        return 'Far East';
      case medievalMagic:
        return 'Medieval Magic';
      case legendaryWeapons:
        return 'Legendary Weapons';
      case darkCreatures:
        return 'Dark Creatures';
    }
  }

  /// Emoji icon for category
  String get icon {
    switch (this) {
      case turkishMyths:
        return '🐺';
      case ancientGreece:
        return '🏛️';
      case vikingIceLands:
        return '⚔️';
      case egyptianDeserts:
        return '🏺';
      case farEast:
        return '🐉';
      case medievalMagic:
        return '🏰';
      case legendaryWeapons:
        return '🗡️';
      case darkCreatures:
        return '👹';
    }
  }

  /// Database slug value
  String get dbValue {
    switch (this) {
      case turkishMyths:
        return 'turkish_myths';
      case ancientGreece:
        return 'ancient_greece';
      case vikingIceLands:
        return 'viking_ice_lands';
      case egyptianDeserts:
        return 'egyptian_deserts';
      case farEast:
        return 'far_east';
      case medievalMagic:
        return 'medieval_magic';
      case legendaryWeapons:
        return 'legendary_weapons';
      case darkCreatures:
        return 'dark_creatures';
    }
  }

  /// Parse from database string
  static CardCategory fromDbValue(String value) {
    switch (value) {
      case 'turkish_myths':
        return turkishMyths;
      case 'ancient_greece':
        return ancientGreece;
      case 'viking_ice_lands':
        return vikingIceLands;
      case 'egyptian_deserts':
        return egyptianDeserts;
      case 'far_east':
        return farEast;
      case 'medieval_magic':
        return medievalMagic;
      case 'legendary_weapons':
        return legendaryWeapons;
      case 'dark_creatures':
        return darkCreatures;
      default:
        return turkishMyths;
    }
  }
}

/// A mythology card from the catalog (96 total)
class MythCard extends Equatable {
  const MythCard({
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
    this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String cardNo;
  final String name;
  final CardCategory category;
  final CardRarity rarity;
  final int power;
  final String? specialSkill;
  final String? description;
  final String? categoryIcon;
  final bool isActive;
  final String? imageUrl;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id, cardNo, name, category, rarity, power,
        specialSkill, description, categoryIcon, isActive, imageUrl, createdAt,
      ];
}

/// A card owned by a user (with quantity for duplicates)
class UserCard extends Equatable {
  const UserCard({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.card,
    required this.quantity,
    required this.firstObtainedAt,
  });

  final String id;
  final String userId;
  final String cardId;
  final MythCard card;
  final int quantity;
  final DateTime firstObtainedAt;

  @override
  List<Object?> get props => [id, userId, cardId, card, quantity, firstObtainedAt];
}

/// Result of opening a card pack (3 cards)
class PackResult {
  const PackResult({
    required this.cards,
    required this.packGlowRarity,
    required this.coinsSpent,
    required this.coinsRemaining,
    this.pityTriggered = false,
  });

  final List<PackCard> cards;
  final CardRarity packGlowRarity;
  final int coinsSpent;
  final int coinsRemaining;
  final bool pityTriggered;
}

/// A single card from a pack opening result
class PackCard {
  const PackCard({
    required this.card,
    required this.isNew,
    required this.currentQuantity,
  });

  final MythCard card;
  final bool isNew;
  final int currentQuantity;
}

/// Aggregate card collection statistics
class UserCardStats extends Equatable {
  const UserCardStats({
    required this.userId,
    this.packsSinceLegendary = 0,
    this.totalPacksOpened = 0,
    this.totalUniqueCards = 0,
  });

  final String userId;
  final int packsSinceLegendary;
  final int totalPacksOpened;
  final int totalUniqueCards;

  @override
  List<Object?> get props => [userId, packsSinceLegendary, totalPacksOpened, totalUniqueCards];
}
