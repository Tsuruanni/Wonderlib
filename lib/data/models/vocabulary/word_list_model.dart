import '../../../domain/entities/word_list.dart';

/// Model for WordList entity - handles JSON serialization
class WordListModel {

  const WordListModel({
    required this.id,
    required this.name,
    required this.description,
    this.level,
    required this.category,
    required this.wordCount,
    this.coverImageUrl,
    this.isSystem = true,
    this.sourceBookId,
    this.unitId,
    this.orderInUnit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WordListModel.fromJson(Map<String, dynamic> json) {
    return WordListModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      level: json['level'] as String?,
      category: json['category'] as String? ?? 'common_words',
      wordCount: json['word_count'] as int? ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
      isSystem: json['is_system'] as bool? ?? true,
      sourceBookId: json['source_book_id'] as String?,
      unitId: json['unit_id'] as String?,
      orderInUnit: json['order_in_unit'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final String description;
  final String? level;
  final String category;
  final int wordCount;
  final String? coverImageUrl;
  final bool isSystem;
  final String? sourceBookId;
  final String? unitId;
  final int? orderInUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': level,
      'category': category,
      'word_count': wordCount,
      'cover_image_url': coverImageUrl,
      'is_system': isSystem,
      'source_book_id': sourceBookId,
      'unit_id': unitId,
      'order_in_unit': orderInUnit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WordList toEntity() {
    return WordList(
      id: id,
      name: name,
      description: description,
      level: level,
      category: _parseCategory(category),
      wordCount: wordCount,
      coverImageUrl: coverImageUrl,
      isSystem: isSystem,
      sourceBookId: sourceBookId,
      unitId: unitId,
      orderInUnit: orderInUnit,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static WordListCategory _parseCategory(String category) {
    switch (category) {
      case 'grade_level':
        return WordListCategory.gradeLevel;
      case 'test_prep':
        return WordListCategory.testPrep;
      case 'thematic':
        return WordListCategory.thematic;
      case 'story_vocab':
        return WordListCategory.storyVocab;
      default:
        return WordListCategory.commonWords;
    }
  }

  static String categoryToString(WordListCategory category) {
    switch (category) {
      case WordListCategory.commonWords:
        return 'common_words';
      case WordListCategory.gradeLevel:
        return 'grade_level';
      case WordListCategory.testPrep:
        return 'test_prep';
      case WordListCategory.thematic:
        return 'thematic';
      case WordListCategory.storyVocab:
        return 'story_vocab';
    }
  }
}
