import '../../domain/entities/tile_theme.dart';

class TileThemeModel {
  const TileThemeModel({
    required this.id,
    required this.name,
    required this.height,
    required this.fallbackColor1,
    required this.fallbackColor2,
    required this.nodePositions,
    required this.sortOrder,
    required this.isActive,
    this.imageUrl,
  });

  factory TileThemeModel.fromJson(Map<String, dynamic> json) {
    final positionsRaw = json['node_positions'];
    final positions = <({double x, double y})>[];
    if (positionsRaw is List) {
      for (final p in positionsRaw) {
        if (p is Map) {
          positions.add((
            x: (p['x'] as num?)?.toDouble() ?? 0.5,
            y: (p['y'] as num?)?.toDouble() ?? 0.5,
          ),);
        }
      }
    }

    return TileThemeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      height: json['height'] as int? ?? 1000,
      fallbackColor1: json['fallback_color_1'] as String? ?? '#2E7D32',
      fallbackColor2: json['fallback_color_2'] as String? ?? '#81C784',
      nodePositions: positions,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
    );
  }

  final String id;
  final String name;
  final int height;
  final String fallbackColor1;
  final String fallbackColor2;
  final List<({double x, double y})> nodePositions;
  final int sortOrder;
  final bool isActive;
  final String? imageUrl;

  TileThemeEntity toEntity() {
    return TileThemeEntity(
      id: id,
      name: name,
      height: height,
      fallbackColor1: fallbackColor1,
      fallbackColor2: fallbackColor2,
      nodePositions: nodePositions,
      sortOrder: sortOrder,
      isActive: isActive,
      imageUrl: imageUrl,
    );
  }
}
