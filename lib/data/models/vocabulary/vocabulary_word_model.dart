import '../../../domain/entities/vocabulary.dart';

/// Model for VocabularyWord entity - handles JSON serialization
class VocabularyWordModel {

  const VocabularyWordModel({
    required this.id,
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    required this.meaningTR,
    this.meaningEN,
    this.exampleSentences = const [],
    this.audioUrl,
    this.imageUrl,
    this.level,
    this.categories = const [],
    this.synonyms = const [],
    this.antonyms = const [],
    required this.createdAt,
    this.sourceBookId,
    this.sourceBookTitle,
  });

  factory VocabularyWordModel.fromJson(Map<String, dynamic> json) {
    // Handle joined book data: books: { title: '...' }
    String? bookTitle;
    final booksData = json['books'];
    if (booksData is Map<String, dynamic>) {
      bookTitle = booksData['title'] as String?;
    }

    return VocabularyWordModel(
      id: json['id'] as String,
      word: json['word'] as String,
      phonetic: json['phonetic'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      meaningTR: json['meaning_tr'] as String? ?? '',
      meaningEN: json['meaning_en'] as String?,
      exampleSentences: _parseStringList(json['example_sentences']),
      audioUrl: json['audio_url'] as String?,
      imageUrl: json['image_url'] as String?,
      level: json['level'] as String?,
      categories: _parseStringList(json['categories']),
      synonyms: _parseStringList(json['synonyms']),
      antonyms: _parseStringList(json['antonyms']),
      createdAt: DateTime.parse(json['created_at'] as String),
      sourceBookId: json['source_book_id'] as String?,
      sourceBookTitle: bookTitle,
    );
  }

  factory VocabularyWordModel.fromEntity(VocabularyWord entity) {
    return VocabularyWordModel(
      id: entity.id,
      word: entity.word,
      phonetic: entity.phonetic,
      partOfSpeech: entity.partOfSpeech,
      meaningTR: entity.meaningTR,
      meaningEN: entity.meaningEN,
      exampleSentences: entity.exampleSentences,
      audioUrl: entity.audioUrl,
      imageUrl: entity.imageUrl,
      level: entity.level,
      categories: entity.categories,
      synonyms: entity.synonyms,
      antonyms: entity.antonyms,
      createdAt: entity.createdAt,
      sourceBookId: entity.sourceBookId,
      sourceBookTitle: entity.sourceBookTitle,
    );
  }
  final String id;
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String meaningTR;
  final String? meaningEN;
  final List<String> exampleSentences;
  final String? audioUrl;
  final String? imageUrl;
  final String? level;
  final List<String> categories;
  final List<String> synonyms;
  final List<String> antonyms;
  final DateTime createdAt;
  final String? sourceBookId;
  final String? sourceBookTitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'phonetic': phonetic,
      'part_of_speech': partOfSpeech,
      'meaning_tr': meaningTR,
      'meaning_en': meaningEN,
      'example_sentences': exampleSentences,
      'audio_url': audioUrl,
      'image_url': imageUrl,
      'level': level,
      'categories': categories,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'created_at': createdAt.toIso8601String(),
      'source_book_id': sourceBookId,
    };
  }

  VocabularyWord toEntity() {
    return VocabularyWord(
      id: id,
      word: word,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      meaningTR: meaningTR,
      meaningEN: meaningEN,
      exampleSentences: exampleSentences,
      audioUrl: audioUrl,
      imageUrl: imageUrl,
      level: level,
      categories: categories,
      synonyms: synonyms,
      antonyms: antonyms,
      createdAt: createdAt,
      sourceBookId: sourceBookId,
      sourceBookTitle: sourceBookTitle,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
