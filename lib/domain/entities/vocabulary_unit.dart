import 'package:equatable/equatable.dart';

/// Represents a grouping unit in the vocabulary learning path.
/// Units are ordered vertically and contain word lists arranged in rows.
/// Note: Color parsing moved to VocabularyUnitColor extension in ui_helpers.dart.
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
