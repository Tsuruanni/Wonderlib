import 'package:equatable/equatable.dart';

class Chapter extends Equatable {
  final String id;
  final String bookId;
  final String title;
  final int orderIndex;
  final String? content;
  final String? audioUrl;
  final List<String> imageUrls;
  final int? wordCount;
  final int? estimatedMinutes;
  final List<ChapterVocabulary> vocabulary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Chapter({
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

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasContent => content != null && content!.isNotEmpty;
  bool get hasImages => imageUrls.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        bookId,
        title,
        orderIndex,
        content,
        audioUrl,
        imageUrls,
        wordCount,
        estimatedMinutes,
        vocabulary,
        createdAt,
        updatedAt,
      ];
}

/// Vocabulary word embedded in chapter
class ChapterVocabulary extends Equatable {
  final String word;
  final String? meaning;
  final String? phonetic;
  final int? startIndex; // Position in content
  final int? endIndex;

  const ChapterVocabulary({
    required this.word,
    this.meaning,
    this.phonetic,
    this.startIndex,
    this.endIndex,
  });

  @override
  List<Object?> get props => [word, meaning, phonetic, startIndex, endIndex];
}
