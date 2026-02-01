import '../../../domain/entities/activity.dart';

/// Model for InlineActivity entity - handles JSON serialization
class InlineActivityModel {
  final String id;
  final String type;
  final int afterParagraphIndex;
  final Map<String, dynamic> content;
  final int xpReward;
  final List<String> vocabularyWords;

  const InlineActivityModel({
    required this.id,
    required this.type,
    required this.afterParagraphIndex,
    required this.content,
    this.xpReward = 5,
    this.vocabularyWords = const [],
  });

  factory InlineActivityModel.fromJson(Map<String, dynamic> json) {
    return InlineActivityModel(
      id: json['id'] as String,
      type: json['type'] as String,
      afterParagraphIndex: json['after_paragraph_index'] as int? ?? 0,
      content: json['content'] as Map<String, dynamic>? ?? {},
      xpReward: json['xp_reward'] as int? ?? 5,
      vocabularyWords: (json['vocabulary_words'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'after_paragraph_index': afterParagraphIndex,
      'content': content,
      'xp_reward': xpReward,
      'vocabulary_words': vocabularyWords,
    };
  }

  InlineActivity toEntity() {
    return InlineActivity(
      id: id,
      type: _parseInlineActivityType(type),
      afterParagraphIndex: afterParagraphIndex,
      content: _parseContent(type, content),
      xpReward: xpReward,
      vocabularyWords: vocabularyWords,
    );
  }

  factory InlineActivityModel.fromEntity(InlineActivity entity) {
    return InlineActivityModel(
      id: entity.id,
      type: _inlineActivityTypeToString(entity.type),
      afterParagraphIndex: entity.afterParagraphIndex,
      content: _contentToJson(entity.type, entity.content),
      xpReward: entity.xpReward,
      vocabularyWords: entity.vocabularyWords,
    );
  }

  static InlineActivityType _parseInlineActivityType(String type) {
    switch (type) {
      case 'true_false':
        return InlineActivityType.trueFalse;
      case 'word_translation':
        return InlineActivityType.wordTranslation;
      case 'find_words':
        return InlineActivityType.findWords;
      default:
        return InlineActivityType.trueFalse;
    }
  }

  static String _inlineActivityTypeToString(InlineActivityType type) {
    switch (type) {
      case InlineActivityType.trueFalse:
        return 'true_false';
      case InlineActivityType.wordTranslation:
        return 'word_translation';
      case InlineActivityType.findWords:
        return 'find_words';
    }
  }

  static InlineActivityContent _parseContent(String type, Map<String, dynamic> json) {
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
      default:
        return TrueFalseContent(
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
    }
  }
}

/// Model for InlineActivityResult entity - handles JSON serialization
class InlineActivityResultModel {
  final String activityId;
  final bool isCorrect;
  final int xpEarned;
  final List<String> wordsLearned;
  final DateTime answeredAt;

  const InlineActivityResultModel({
    required this.activityId,
    required this.isCorrect,
    required this.xpEarned,
    this.wordsLearned = const [],
    required this.answeredAt,
  });

  factory InlineActivityResultModel.fromJson(Map<String, dynamic> json) {
    return InlineActivityResultModel(
      activityId: json['activity_id'] as String,
      isCorrect: json['is_correct'] as bool? ?? false,
      xpEarned: json['xp_earned'] as int? ?? 0,
      wordsLearned:
          (json['words_learned'] as List<dynamic>?)?.map((w) => w as String).toList() ?? [],
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activity_id': activityId,
      'is_correct': isCorrect,
      'xp_earned': xpEarned,
      'words_learned': wordsLearned,
      'answered_at': answeredAt.toIso8601String(),
    };
  }

  InlineActivityResult toEntity() {
    return InlineActivityResult(
      activityId: activityId,
      isCorrect: isCorrect,
      xpEarned: xpEarned,
      wordsLearned: wordsLearned,
      answeredAt: answeredAt,
    );
  }

  factory InlineActivityResultModel.fromEntity(InlineActivityResult entity) {
    return InlineActivityResultModel(
      activityId: entity.activityId,
      isCorrect: entity.isCorrect,
      xpEarned: entity.xpEarned,
      wordsLearned: entity.wordsLearned,
      answeredAt: entity.answeredAt,
    );
  }
}
