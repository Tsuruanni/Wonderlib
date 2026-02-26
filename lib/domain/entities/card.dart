import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

export 'package:owlio_shared/src/enums/card_rarity.dart';
export 'package:owlio_shared/src/enums/card_category.dart';

/// Emoji icons for card categories (UI-specific)
extension CardCategoryIcon on CardCategory {
  String get icon {
    switch (this) {
      case CardCategory.turkishMyths:
        return '🐺';
      case CardCategory.ancientGreece:
        return '🏛️';
      case CardCategory.vikingIceLands:
        return '⚔️';
      case CardCategory.egyptianDeserts:
        return '🏺';
      case CardCategory.farEast:
        return '🐉';
      case CardCategory.medievalMagic:
        return '🏰';
      case CardCategory.legendaryWeapons:
        return '🗡️';
      case CardCategory.darkCreatures:
        return '👹';
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
class PackResult extends Equatable {
  const PackResult({
    required this.cards,
    required this.packGlowRarity,
    this.packsRemaining = 0,
    this.pityTriggered = false,
  });

  final List<PackCard> cards;
  final CardRarity packGlowRarity;
  final int packsRemaining;
  final bool pityTriggered;

  @override
  List<Object?> get props => [cards, packGlowRarity, packsRemaining, pityTriggered];
}

/// Result of buying a card pack (coins → inventory)
class BuyPackResult extends Equatable {
  const BuyPackResult({
    required this.coinsSpent,
    required this.coinsRemaining,
    required this.unopenedPacks,
  });

  final int coinsSpent;
  final int coinsRemaining;
  final int unopenedPacks;

  @override
  List<Object?> get props => [coinsSpent, coinsRemaining, unopenedPacks];
}

/// A single card from a pack opening result
class PackCard extends Equatable {
  const PackCard({
    required this.card,
    required this.isNew,
    required this.currentQuantity,
  });

  final MythCard card;
  final bool isNew;
  final int currentQuantity;

  @override
  List<Object?> get props => [card, isNew, currentQuantity];
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
