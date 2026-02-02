import 'package:equatable/equatable.dart';

/// Type of content block
enum ContentBlockType {
  text,
  image,
  audio,
  activity,
}

/// A structured content block within a chapter
class ContentBlock extends Equatable {
  const ContentBlock({
    required this.id,
    required this.chapterId,
    required this.orderIndex,
    required this.type,
    this.text,
    this.audioUrl,
    this.wordTimings = const [],
    this.audioStartMs,
    this.audioEndMs,
    this.imageUrl,
    this.caption,
    this.activityId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory for creating an empty/placeholder block
  factory ContentBlock.empty() => ContentBlock(
        id: '',
        chapterId: '',
        orderIndex: 0,
        type: ContentBlockType.text,
        audioStartMs: null,
        audioEndMs: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  final String id;
  final String chapterId;
  final int orderIndex;
  final ContentBlockType type;

  // Text block fields
  final String? text;
  final String? audioUrl;
  final List<WordTiming> wordTimings;

  /// Start position of this block within chapter audio (milliseconds)
  final int? audioStartMs;

  /// End position of this block within chapter audio (milliseconds)
  final int? audioEndMs;

  // Image block fields
  final String? imageUrl;
  final String? caption;

  // Activity block fields
  final String? activityId;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Helper getters
  bool get isTextBlock => type == ContentBlockType.text;
  bool get isImageBlock => type == ContentBlockType.image;
  bool get isAudioBlock => type == ContentBlockType.audio;
  bool get isActivityBlock => type == ContentBlockType.activity;

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasWordTimings => wordTimings.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Get total audio duration in milliseconds (from last word timing)
  int? get audioDurationMs {
    if (wordTimings.isEmpty) return null;
    return wordTimings.last.endMs;
  }

  /// Audio duration for this block within chapter audio (milliseconds)
  int? get audioBlockDurationMs {
    if (audioStartMs == null || audioEndMs == null) return null;
    return audioEndMs! - audioStartMs!;
  }

  @override
  List<Object?> get props => [
        id,
        chapterId,
        orderIndex,
        type,
        text,
        audioUrl,
        wordTimings,
        audioStartMs,
        audioEndMs,
        imageUrl,
        caption,
        activityId,
        createdAt,
        updatedAt,
      ];
}

/// Word timing data for audio synchronization
class WordTiming extends Equatable {
  const WordTiming({
    required this.word,
    required this.startIndex,
    required this.endIndex,
    required this.startMs,
    required this.endMs,
  });

  final String word;
  final int startIndex; // Character position in text
  final int endIndex;
  final int startMs; // Audio start time in milliseconds
  final int endMs; // Audio end time in milliseconds

  /// Check if this word is active at the given audio position
  bool isActiveAt(int positionMs) {
    return positionMs >= startMs && positionMs < endMs;
  }

  /// Duration of this word in milliseconds
  int get durationMs => endMs - startMs;

  @override
  List<Object?> get props => [word, startIndex, endIndex, startMs, endMs];
}
