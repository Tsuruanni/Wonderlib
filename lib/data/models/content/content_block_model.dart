import '../../../domain/entities/content/content_block.dart';

/// Data model for ContentBlock - handles JSON serialization
class ContentBlockModel {
  const ContentBlockModel({
    required this.id,
    required this.chapterId,
    required this.orderIndex,
    required this.type,
    this.text,
    this.audioUrl,
    this.wordTimings = const [],
    this.imageUrl,
    this.caption,
    this.activityId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentBlockModel.fromJson(Map<String, dynamic> json) {
    final wordTimingsJson = json['word_timings'] as List<dynamic>?;
    final wordTimings = wordTimingsJson
            ?.map((w) => WordTimingModel.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];

    return ContentBlockModel(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      orderIndex: json['order_index'] as int,
      type: _parseBlockType(json['type'] as String),
      text: json['text'] as String?,
      audioUrl: json['audio_url'] as String?,
      wordTimings: wordTimings,
      imageUrl: json['image_url'] as String?,
      caption: json['caption'] as String?,
      activityId: json['activity_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory ContentBlockModel.fromEntity(ContentBlock entity) {
    return ContentBlockModel(
      id: entity.id,
      chapterId: entity.chapterId,
      orderIndex: entity.orderIndex,
      type: entity.type,
      text: entity.text,
      audioUrl: entity.audioUrl,
      wordTimings:
          entity.wordTimings.map((w) => WordTimingModel.fromEntity(w)).toList(),
      imageUrl: entity.imageUrl,
      caption: entity.caption,
      activityId: entity.activityId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  final String id;
  final String chapterId;
  final int orderIndex;
  final ContentBlockType type;
  final String? text;
  final String? audioUrl;
  final List<WordTimingModel> wordTimings;
  final String? imageUrl;
  final String? caption;
  final String? activityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  static ContentBlockType _parseBlockType(String type) {
    switch (type) {
      case 'text':
        return ContentBlockType.text;
      case 'image':
        return ContentBlockType.image;
      case 'audio':
        return ContentBlockType.audio;
      case 'activity':
        return ContentBlockType.activity;
      default:
        return ContentBlockType.text;
    }
  }

  static String _blockTypeToString(ContentBlockType type) {
    switch (type) {
      case ContentBlockType.text:
        return 'text';
      case ContentBlockType.image:
        return 'image';
      case ContentBlockType.audio:
        return 'audio';
      case ContentBlockType.activity:
        return 'activity';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'order_index': orderIndex,
      'type': _blockTypeToString(type),
      'text': text,
      'audio_url': audioUrl,
      'word_timings': wordTimings.map((w) => w.toJson()).toList(),
      'image_url': imageUrl,
      'caption': caption,
      'activity_id': activityId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ContentBlock toEntity() {
    return ContentBlock(
      id: id,
      chapterId: chapterId,
      orderIndex: orderIndex,
      type: type,
      text: text,
      audioUrl: audioUrl,
      wordTimings: wordTimings.map((w) => w.toEntity()).toList(),
      imageUrl: imageUrl,
      caption: caption,
      activityId: activityId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Data model for WordTiming - handles JSON serialization
class WordTimingModel {
  const WordTimingModel({
    required this.word,
    required this.startIndex,
    required this.endIndex,
    required this.startMs,
    required this.endMs,
  });

  factory WordTimingModel.fromJson(Map<String, dynamic> json) {
    return WordTimingModel(
      word: json['word'] as String,
      startIndex: json['startIndex'] as int,
      endIndex: json['endIndex'] as int,
      startMs: json['startMs'] as int,
      endMs: json['endMs'] as int,
    );
  }

  factory WordTimingModel.fromEntity(WordTiming entity) {
    return WordTimingModel(
      word: entity.word,
      startIndex: entity.startIndex,
      endIndex: entity.endIndex,
      startMs: entity.startMs,
      endMs: entity.endMs,
    );
  }

  final String word;
  final int startIndex;
  final int endIndex;
  final int startMs;
  final int endMs;

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'startMs': startMs,
      'endMs': endMs,
    };
  }

  WordTiming toEntity() {
    return WordTiming(
      word: word,
      startIndex: startIndex,
      endIndex: endIndex,
      startMs: startMs,
      endMs: endMs,
    );
  }
}
