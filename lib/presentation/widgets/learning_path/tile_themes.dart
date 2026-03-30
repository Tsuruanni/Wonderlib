import 'package:flutter/material.dart';

/// A map tile theme with background asset and node positions.
class TileTheme {
  const TileTheme({
    required this.name,
    required this.assetPath,
    required this.nodePositions,
    required this.fallbackColors,
    this.height = 1000.0,
    this.imageUrl,
  });

  /// Theme display name (for debugging).
  final String name;

  /// Asset path for the background image (legacy/local).
  final String assetPath;

  /// Remote image URL from Supabase storage (takes priority over assetPath).
  final String? imageUrl;

  /// Tile height in logical pixels (varies per theme).
  final double height;

  /// Node positions as percentages (0.0–1.0) of tile width/height.
  /// Index 0 is the topmost node, last is the bottommost.
  final List<Offset> nodePositions;

  /// Gradient colors for placeholder mode (before real assets exist).
  final List<Color> fallbackColors;
}

/// Tile render dimensions (logical pixels).
const kTileWidth = 800.0;

/// Height of the unit divider widget between tiles.
const kDividerHeight = 60.0;

/// All available tile themes. Units cycle through these.
const kTileThemes = <TileTheme>[
  TileTheme(
    name: 'Forest',
    assetPath: 'assets/images/map_tiles/tile_forest.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.35, 0.22),
      Offset(0.58, 0.36),
      Offset(0.32, 0.50),
      Offset(0.55, 0.64),
      Offset(0.40, 0.78),
      Offset(0.50, 0.92),
    ],
    fallbackColors: [Color(0xFF2E7D32), Color(0xFF81C784)],
  ),
  TileTheme(
    name: 'Beach',
    assetPath: 'assets/images/map_tiles/tile_beach.webp',
    nodePositions: [
      Offset(0.48, 0.08),
      Offset(0.62, 0.22),
      Offset(0.38, 0.36),
      Offset(0.55, 0.50),
      Offset(0.35, 0.64),
      Offset(0.52, 0.78),
      Offset(0.45, 0.92),
    ],
    fallbackColors: [Color(0xFF0288D1), Color(0xFF81D4FA)],
  ),
  TileTheme(
    name: 'Mountain',
    assetPath: 'assets/images/map_tiles/tile_mountain.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.38, 0.22),
      Offset(0.60, 0.36),
      Offset(0.35, 0.50),
      Offset(0.58, 0.64),
      Offset(0.42, 0.78),
      Offset(0.50, 0.92),
    ],
    fallbackColors: [Color(0xFF546E7A), Color(0xFFB0BEC5)],
  ),
  TileTheme(
    name: 'Desert',
    assetPath: 'assets/images/map_tiles/tile_desert.webp',
    nodePositions: [
      Offset(0.52, 0.08),
      Offset(0.36, 0.22),
      Offset(0.56, 0.36),
      Offset(0.40, 0.50),
      Offset(0.60, 0.64),
      Offset(0.38, 0.78),
      Offset(0.48, 0.92),
    ],
    fallbackColors: [Color(0xFFE65100), Color(0xFFFFCC80)],
  ),
  TileTheme(
    name: 'Garden',
    assetPath: 'assets/images/map_tiles/tile_garden.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.40, 0.22),
      Offset(0.58, 0.36),
      Offset(0.35, 0.50),
      Offset(0.55, 0.64),
      Offset(0.45, 0.78),
      Offset(0.50, 0.92),
    ],
    fallbackColors: [Color(0xFFC2185B), Color(0xFFF48FB1)],
  ),
  TileTheme(
    name: 'Winter',
    assetPath: 'assets/images/map_tiles/tile_winter.webp',
    nodePositions: [
      Offset(0.48, 0.08),
      Offset(0.60, 0.22),
      Offset(0.36, 0.36),
      Offset(0.58, 0.50),
      Offset(0.38, 0.64),
      Offset(0.52, 0.78),
      Offset(0.45, 0.92),
    ],
    fallbackColors: [Color(0xFF1565C0), Color(0xFFBBDEFB)],
  ),
];

/// Returns the theme for a given unit index (cycles through themes).
TileTheme tileThemeForUnit(int unitIndex) {
  return kTileThemes[unitIndex % kTileThemes.length];
}
