import '../../../domain/entities/avatar.dart';

class AvatarItemCategoryModel {
  const AvatarItemCategoryModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.zIndex,
    this.sortOrder = 0,
  });

  factory AvatarItemCategoryModel.fromJson(Map<String, dynamic> json) {
    return AvatarItemCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      zIndex: json['z_index'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String displayName;
  final int zIndex;
  final int sortOrder;

  AvatarItemCategory toEntity() {
    return AvatarItemCategory(
      id: id,
      name: name,
      displayName: displayName,
      zIndex: zIndex,
      sortOrder: sortOrder,
    );
  }
}
