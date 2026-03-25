import '../../../domain/entities/avatar.dart';
import 'avatar_item_model.dart';

class UserAvatarItemModel {
  const UserAvatarItemModel({
    required this.userId,
    required this.item,
    required this.isEquipped,
    required this.purchasedAt,
  });

  factory UserAvatarItemModel.fromJson(Map<String, dynamic> json) {
    return UserAvatarItemModel(
      userId: json['user_id'] as String,
      item: AvatarItemModel.fromJson(
        json['avatar_items'] as Map<String, dynamic>,
      ),
      isEquipped: json['is_equipped'] as bool? ?? false,
      purchasedAt: DateTime.parse(json['purchased_at'] as String),
    );
  }

  final String userId;
  final AvatarItemModel item;
  final bool isEquipped;
  final DateTime purchasedAt;

  UserAvatarItem toEntity() {
    return UserAvatarItem(
      userId: userId,
      item: item.toEntity(),
      isEquipped: isEquipped,
      purchasedAt: purchasedAt,
    );
  }
}
