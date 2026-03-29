import '../../../domain/entities/vocabulary_unit.dart';

/// Model for VocabularyUnit entity - handles JSON deserialization.
/// Read-only: the Flutter app only reads units (admin panel creates them).
class VocabularyUnitModel {
  const VocabularyUnitModel({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
    this.color,
    this.icon,
    this.isActive = true,
    this.tileThemeId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VocabularyUnitModel.fromJson(Map<String, dynamic> json) {
    return VocabularyUnitModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      tileThemeId: json['tile_theme_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final String? description;
  final int sortOrder;
  final String? color;
  final String? icon;
  final bool isActive;
  final String? tileThemeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  VocabularyUnit toEntity() {
    return VocabularyUnit(
      id: id,
      name: name,
      description: description,
      sortOrder: sortOrder,
      color: color,
      icon: icon,
      isActive: isActive,
      tileThemeId: tileThemeId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
