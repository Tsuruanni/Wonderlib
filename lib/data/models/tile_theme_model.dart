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
      imageUrl: _rewriteToRenderEndpoint(json['image_url'] as String?),
    );
  }

  /// Rewrites a raw Supabase Storage URL to the image-transformation endpoint
  /// so the CDN returns a server-resized copy. Tile source images can be
  /// 3072×11000 (~34M px) — above the decode limit of strict mobile browsers
  /// like Samsung Internet, which silently render transparent. Asking the
  /// server for width=1600 brings the image well under any browser limit
  /// (≤9M px) and shrinks both transfer size and client decode RAM.
  static String? _rewriteToRenderEndpoint(String? url) {
    if (url == null || url.isEmpty) return url;
    const objectPath = '/storage/v1/object/public/';
    const renderPath = '/storage/v1/render/image/public/';
    if (!url.contains(objectPath)) return url;
    final rewritten = url.replaceFirst(objectPath, renderPath);
    final separator = rewritten.contains('?') ? '&' : '?';
    return '$rewritten${separator}width=1600&quality=80';
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
