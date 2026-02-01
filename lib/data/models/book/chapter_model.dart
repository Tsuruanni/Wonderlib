import '../../../domain/entities/chapter.dart';

/// Data model for Chapter - handles JSON serialization
class ChapterModel {
  final String id;
  final String bookId;
  final String title;
  final int orderIndex;
  final String? content;
  final String? audioUrl;
  final List<String> imageUrls;
  final int? wordCount;
  final int? estimatedMinutes;
  final List<ChapterVocabularyModel> vocabulary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterModel({
    required this.id,
    required this.bookId,
    required this.title,
    required this.orderIndex,
    this.content,
    this.audioUrl,
    this.imageUrls = const [],
    this.wordCount,
    this.estimatedMinutes,
    this.vocabulary = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    final vocabularyJson = json['vocabulary'] as List<dynamic>?;
    final vocabulary = vocabularyJson
            ?.map((v) => ChapterVocabularyModel.fromJson(v as Map<String, dynamic>))
            .toList() ??
        [];

    final imageUrlsJson = json['image_urls'] as List<dynamic>?;
    final imageUrls = imageUrlsJson?.map((url) => url as String).toList() ?? [];

    return ChapterModel(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      title: json['title'] as String,
      orderIndex: json['order_index'] as int,
      content: json['content'] as String?,
      audioUrl: json['audio_url'] as String?,
      imageUrls: imageUrls,
      wordCount: json['word_count'] as int?,
      estimatedMinutes: json['estimated_minutes'] as int?,
      vocabulary: vocabulary,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'title': title,
      'order_index': orderIndex,
      'content': content,
      'audio_url': audioUrl,
      'image_urls': imageUrls,
      'word_count': wordCount,
      'estimated_minutes': estimatedMinutes,
      'vocabulary': vocabulary.map((v) => v.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Chapter toEntity() {
    return Chapter(
      id: id,
      bookId: bookId,
      title: title,
      orderIndex: orderIndex,
      content: content,
      audioUrl: audioUrl,
      imageUrls: imageUrls,
      wordCount: wordCount,
      estimatedMinutes: estimatedMinutes,
      vocabulary: vocabulary.map((v) => v.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ChapterModel.fromEntity(Chapter entity) {
    return ChapterModel(
      id: entity.id,
      bookId: entity.bookId,
      title: entity.title,
      orderIndex: entity.orderIndex,
      content: entity.content,
      audioUrl: entity.audioUrl,
      imageUrls: entity.imageUrls,
      wordCount: entity.wordCount,
      estimatedMinutes: entity.estimatedMinutes,
      vocabulary: entity.vocabulary
          .map((v) => ChapterVocabularyModel.fromEntity(v))
          .toList(),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}

/// Data model for ChapterVocabulary
class ChapterVocabularyModel {
  final String word;
  final String? meaning;
  final String? phonetic;
  final int? startIndex;
  final int? endIndex;

  const ChapterVocabularyModel({
    required this.word,
    this.meaning,
    this.phonetic,
    this.startIndex,
    this.endIndex,
  });

  factory ChapterVocabularyModel.fromJson(Map<String, dynamic> json) {
    return ChapterVocabularyModel(
      word: json['word'] as String,
      meaning: json['meaning'] as String?,
      phonetic: json['phonetic'] as String?,
      startIndex: json['startIndex'] as int?,
      endIndex: json['endIndex'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'meaning': meaning,
      'phonetic': phonetic,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }

  ChapterVocabulary toEntity() {
    return ChapterVocabulary(
      word: word,
      meaning: meaning,
      phonetic: phonetic,
      startIndex: startIndex,
      endIndex: endIndex,
    );
  }

  factory ChapterVocabularyModel.fromEntity(ChapterVocabulary entity) {
    return ChapterVocabularyModel(
      word: entity.word,
      meaning: entity.meaning,
      phonetic: entity.phonetic,
      startIndex: entity.startIndex,
      endIndex: entity.endIndex,
    );
  }
}
