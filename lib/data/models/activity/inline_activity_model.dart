import 'package:flutter/foundation.dart';

import '../../../domain/entities/activity.dart';

/// Model for InlineActivity entity - handles JSON serialization
class InlineActivityModel {

  const InlineActivityModel({
    required this.id,
    required this.type,
    required this.afterParagraphIndex,
    required this.content,
    this.vocabularyWords = const [],
  });

  factory InlineActivityModel.fromEntity(InlineActivity entity) {
    return InlineActivityModel(
      id: entity.id,
      type: entity.type.dbValue,
      afterParagraphIndex: entity.afterParagraphIndex,
      content: _contentToJson(entity.type, entity.content),
      vocabularyWords: entity.vocabularyWords,
    );
  }

  /// Returns null for unknown activity types (filtered out by repository).
  static InlineActivityModel? fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final knownTypes = InlineActivityType.values.map((e) => e.dbValue).toSet();
    if (typeStr == null || !knownTypes.contains(typeStr)) {
      debugPrint('⚠️ Unknown inline activity type: $typeStr, skipping');
      return null;
    }

    return InlineActivityModel(
      id: json['id'] as String,
      type: typeStr,
      afterParagraphIndex: json['after_paragraph_index'] as int? ?? 0,
      content: json['content'] as Map<String, dynamic>? ?? {},
      vocabularyWords: (json['vocabulary_words'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
    );
  }

  final String id;
  final String type;
  final int afterParagraphIndex;
  final Map<String, dynamic> content;
  final List<String> vocabularyWords;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'after_paragraph_index': afterParagraphIndex,
      'content': content,
      'vocabulary_words': vocabularyWords,
    };
  }

  InlineActivity toEntity() {
    return InlineActivity(
      id: id,
      type: InlineActivityType.fromDbValue(type),
      afterParagraphIndex: afterParagraphIndex,
      content: _parseContent(type, content),
      vocabularyWords: vocabularyWords,
    );
  }

  static InlineActivityContent _parseContent(
      String type, Map<String, dynamic> json,) {
    switch (type) {
      case 'true_false':
        return TrueFalseContent(
          statement: json['statement'] as String? ?? '',
          correctAnswer: json['correct_answer'] as bool? ?? true,
        );
      case 'word_translation':
        return WordTranslationContent(
          word: json['word'] as String? ?? '',
          correctAnswer: json['correct_answer'] as String? ?? '',
          options: (json['options'] as List<dynamic>?)?.map((o) => o as String).toList() ?? [],
        );
      case 'find_words':
        return FindWordsContent(
          instruction: json['instruction'] as String? ?? '',
          options: (json['options'] as List<dynamic>?)?.map((o) => o as String).toList() ?? [],
          correctAnswers:
              (json['correct_answers'] as List<dynamic>?)?.map((a) => a as String).toList() ?? [],
        );
      case 'matching':
        return MatchingContent(
          instruction: json['instruction'] as String? ?? '',
          pairs: (json['pairs'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((p) => ActivityMatchingPair(
                        left: p['left'] as String? ?? '',
                        right: p['right'] as String? ?? '',
                      ),)
                  .toList() ??
              [],
        );
      default:
        return const TrueFalseContent(
          statement: '',
          correctAnswer: true,
        );
    }
  }

  static Map<String, dynamic> _contentToJson(InlineActivityType type, InlineActivityContent content) {
    switch (type) {
      case InlineActivityType.trueFalse:
        final trueFalse = content as TrueFalseContent;
        return {
          'statement': trueFalse.statement,
          'correct_answer': trueFalse.correctAnswer,
        };
      case InlineActivityType.wordTranslation:
        final wordTrans = content as WordTranslationContent;
        return {
          'word': wordTrans.word,
          'correct_answer': wordTrans.correctAnswer,
          'options': wordTrans.options,
        };
      case InlineActivityType.findWords:
        final findWords = content as FindWordsContent;
        return {
          'instruction': findWords.instruction,
          'options': findWords.options,
          'correct_answers': findWords.correctAnswers,
        };
      case InlineActivityType.matching:
        final matching = content as MatchingContent;
        return {
          'instruction': matching.instruction,
          'pairs': matching.pairs
              .map((p) => {'left': p.left, 'right': p.right})
              .toList(),
        };
    }
  }
}
