import 'dart:ui';

import 'package:equatable/equatable.dart';

/// Represents a grouping unit in the vocabulary learning path.
/// Units are ordered vertically and contain word lists arranged in rows.
class VocabularyUnit extends Equatable {
  const VocabularyUnit({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
    this.color,
    this.icon,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int sortOrder;
  final String? color; // Hex string: "#58CC02"
  final String? icon; // Emoji: "🌟"
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Parse hex color string to Flutter Color. Falls back to green.
  Color get parsedColor {
    if (color == null || color!.length < 7) return const Color(0xFF58CC02);
    try {
      return Color(int.parse(color!.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF58CC02);
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        sortOrder,
        color,
        icon,
        isActive,
        createdAt,
        updatedAt,
      ];
}
