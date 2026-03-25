import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/avatar.dart';
import 'avatar_item_category_model.dart';

class AvatarItemModel {
  const AvatarItemModel({
    required this.id,
    required this.category,
    required this.name,
    required this.displayName,
    required this.rarity,
    required this.coinPrice,
    required this.imageUrl,
    this.previewUrl,
  });

  factory AvatarItemModel.fromJson(Map<String, dynamic> json) {
    return AvatarItemModel(
      id: json['id'] as String,
      category: AvatarItemCategoryModel.fromJson(
        json['avatar_item_categories'] as Map<String, dynamic>,
      ),
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      rarity: CardRarity.fromDbValue(json['rarity'] as String),
      coinPrice: json['coin_price'] as int,
      imageUrl: json['image_url'] as String,
      previewUrl: json['preview_url'] as String?,
    );
  }

  final String id;
  final AvatarItemCategoryModel category;
  final String name;
  final String displayName;
  final CardRarity rarity;
  final int coinPrice;
  final String imageUrl;
  final String? previewUrl;

  AvatarItem toEntity() {
    return AvatarItem(
      id: id,
      category: category.toEntity(),
      name: name,
      displayName: displayName,
      rarity: rarity,
      coinPrice: coinPrice,
      imageUrl: imageUrl,
      previewUrl: previewUrl,
    );
  }
}
