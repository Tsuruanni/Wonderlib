import '../../../domain/entities/avatar.dart';

class AvatarBaseModel {
  const AvatarBaseModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  factory AvatarBaseModel.fromJson(Map<String, dynamic> json) {
    return AvatarBaseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      imageUrl: json['image_url'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String displayName;
  final String imageUrl;
  final int sortOrder;

  AvatarBase toEntity() {
    return AvatarBase(
      id: id,
      name: name,
      displayName: displayName,
      imageUrl: imageUrl,
      sortOrder: sortOrder,
    );
  }
}
