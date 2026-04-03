import '../../../domain/entities/avatar.dart';

class EquippedAvatarModel {
  const EquippedAvatarModel({this.baseUrl, this.layers = const [], this.hairColor});

  factory EquippedAvatarModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EquippedAvatarModel();
    return EquippedAvatarModel(
      baseUrl: json['base_url'] as String?,
      layers: (json['layers'] as List<dynamic>?)
              ?.map((l) => AvatarLayerModel.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      hairColor: json['hair_color'] as String?,
    );
  }

  final String? baseUrl;
  final List<AvatarLayerModel> layers;
  final String? hairColor;

  EquippedAvatar toEntity() {
    return EquippedAvatar(
      baseUrl: baseUrl,
      layers: layers.map((l) => l.toEntity()).toList(),
      hairColor: hairColor,
    );
  }
}

class AvatarLayerModel {
  const AvatarLayerModel({required this.zIndex, required this.url, this.category});

  factory AvatarLayerModel.fromJson(Map<String, dynamic> json) {
    return AvatarLayerModel(
      zIndex: json['z'] as int,
      url: json['url'] as String,
      category: json['cat'] as String?,
    );
  }

  final int zIndex;
  final String url;
  final String? category;

  AvatarLayer toEntity() => AvatarLayer(zIndex: zIndex, url: url, category: category);
}
