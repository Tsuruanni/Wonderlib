import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// Base animal avatar (6 total, all free)
class AvatarBase extends Equatable {
  const AvatarBase({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String displayName;
  final String imageUrl;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, displayName, imageUrl, sortOrder];
}

/// Dynamic accessory slot category
class AvatarItemCategory extends Equatable {
  const AvatarItemCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.zIndex,
    this.sortOrder = 0,
    this.isRequired = true,
  });

  final String id;
  final String name;
  final String displayName;
  final int zIndex;
  final int sortOrder;
  final bool isRequired;

  @override
  List<Object?> get props => [id, name, displayName, zIndex, sortOrder, isRequired];
}

/// Accessory item from the catalog
class AvatarItem extends Equatable {
  const AvatarItem({
    required this.id,
    required this.category,
    required this.name,
    required this.displayName,
    required this.rarity,
    required this.coinPrice,
    required this.imageUrl,
    this.previewUrl,
    this.gender = 'unisex',
  });

  final String id;
  final AvatarItemCategory category;
  final String name;
  final String displayName;
  final CardRarity rarity;
  final int coinPrice;
  final String imageUrl;
  final String? previewUrl;
  final String gender;

  @override
  List<Object?> get props => [id, category, name, displayName, rarity, coinPrice, imageUrl, previewUrl, gender];
}

/// An item owned by a user
class UserAvatarItem extends Equatable {
  const UserAvatarItem({
    required this.userId,
    required this.item,
    required this.isEquipped,
    required this.purchasedAt,
  });

  final String userId;
  final AvatarItem item;
  final bool isEquipped;
  final DateTime purchasedAt;

  @override
  List<Object?> get props => [userId, item, isEquipped, purchasedAt];
}

/// A single render layer in the composed avatar
class AvatarLayer extends Equatable {
  const AvatarLayer({required this.zIndex, required this.url, this.category});

  final int zIndex;
  final String url;
  final String? category;

  @override
  List<Object?> get props => [zIndex, url, category];
}

/// Composed avatar state (parsed from avatar_equipped_cache JSONB)
class EquippedAvatar extends Equatable {
  const EquippedAvatar({this.baseUrl, this.layers = const [], this.hairColor});

  final String? baseUrl;
  final List<AvatarLayer> layers;
  final String? hairColor;

  bool get isEmpty => baseUrl == null && layers.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  List<Object?> get props => [baseUrl, layers, hairColor];
}

/// Result of buying an avatar item
class BuyAvatarItemResult extends Equatable {
  const BuyAvatarItemResult({
    required this.coinsRemaining,
    required this.itemId,
  });

  final int coinsRemaining;
  final String itemId;

  @override
  List<Object?> get props => [coinsRemaining, itemId];
}
