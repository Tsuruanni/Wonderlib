import 'package:equatable/equatable.dart';

/// A configurable map tile theme for the learning path.
class TileThemeEntity extends Equatable {
  const TileThemeEntity({
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

  final String id;
  final String name;
  final int height;
  final String fallbackColor1;
  final String fallbackColor2;
  final List<({double x, double y})> nodePositions;
  final int sortOrder;
  final bool isActive;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, name, height, fallbackColor1, fallbackColor2, nodePositions, sortOrder, isActive, imageUrl];
}
