import '../../../domain/entities/book_quiz.dart';

/// Model for BookQuiz entity - handles JSON serialization
class BookQuizModel {
  const BookQuizModel({
    required this.id,
    required this.bookId,
    required this.title,
    this.instructions,
    this.passingScore = 70.0,
    this.totalPoints = 10,
    this.isPublished = false,
    this.questions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookQuizModel.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['book_quiz_questions'] as List<dynamic>? ?? [];
    return BookQuizModel(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      title: json['title'] as String? ?? 'Final Quiz',
      instructions: json['instructions'] as String?,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 70.0,
      totalPoints: json['total_points'] as int? ?? 10,
      isPublished: json['is_published'] as bool? ?? false,
      questions: questionsJson
          .whereType<Map<String, dynamic>>()
          .map((q) => BookQuizQuestionModel.fromJson(q))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory BookQuizModel.fromEntity(BookQuiz entity) {
    return BookQuizModel(
      id: entity.id,
      bookId: entity.bookId,
      title: entity.title,
      instructions: entity.instructions,
      passingScore: entity.passingScore,
      totalPoints: entity.totalPoints,
      isPublished: entity.isPublished,
      questions: entity.questions
          .map((q) => BookQuizQuestionModel.fromEntity(q))
          .toList(),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  final String id;
  final String bookId;
  final String title;
  final String? instructions;
  final double passingScore;
  final int totalPoints;
  final bool isPublished;
  final List<BookQuizQuestionModel> questions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'title': title,
      'instructions': instructions,
      'passing_score': passingScore,
      'total_points': totalPoints,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BookQuiz toEntity() {
    return BookQuiz(
      id: id,
      bookId: bookId,
      title: title,
      instructions: instructions,
      passingScore: passingScore,
      totalPoints: totalPoints,
      isPublished: isPublished,
      questions: questions.map((q) => q.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Model for BookQuizQuestion - handles polymorphic content parsing
class BookQuizQuestionModel {
  const BookQuizQuestionModel({
    required this.id,
    required this.quizId,
    required this.type,
    required this.orderIndex,
    required this.question,
    required this.content,
    this.explanation,
    this.points = 1,
  });

  factory BookQuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return BookQuizQuestionModel(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      type: json['type'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      question: json['question'] as String? ?? '',
      content: json['content'] as Map<String, dynamic>? ?? {},
      explanation: json['explanation'] as String?,
      points: json['points'] as int? ?? 1,
    );
  }

  factory BookQuizQuestionModel.fromEntity(BookQuizQuestion entity) {
    return BookQuizQuestionModel(
      id: entity.id,
      quizId: entity.quizId,
      type: entity.type.dbValue,
      orderIndex: entity.orderIndex,
      question: entity.question,
      content: _contentToJson(entity.type, entity.content),
      explanation: entity.explanation,
      points: entity.points,
    );
  }

  final String id;
  final String quizId;
  final String type;
  final int orderIndex;
  final String question;
  final Map<String, dynamic> content;
  final String? explanation;
  final int points;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'type': type,
      'order_index': orderIndex,
      'question': question,
      'content': content,
      'explanation': explanation,
      'points': points,
    };
  }

  BookQuizQuestion toEntity() {
    return BookQuizQuestion(
      id: id,
      quizId: quizId,
      type: BookQuizQuestionType.fromDbValue(type),
      orderIndex: orderIndex,
      question: question,
      content: _parseContent(type, content),
      explanation: explanation,
      points: points,
    );
  }

  // ============================================
  // POLYMORPHIC CONTENT PARSING
  // ============================================

  static BookQuizQuestionContent _parseContent(
    String type,
    Map<String, dynamic> json,
  ) {
    switch (type) {
      case 'multiple_choice':
        return MultipleChoiceContent(
          options: (json['options'] as List<dynamic>?)
                  ?.map((o) => o as String)
                  .toList() ??
              [],
          correctAnswer: json['correct_answer'] as String? ?? '',
        );

      case 'fill_blank':
        return FillBlankContent(
          sentence: json['sentence'] as String? ?? '',
          correctAnswer: json['correct_answer'] as String? ?? '',
          acceptAlternatives: (json['accept_alternatives'] as List<dynamic>?)
                  ?.map((a) => a as String)
                  .toList() ??
              [],
        );

      case 'event_sequencing':
        return EventSequencingContent(
          events: (json['events'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
          correctOrder: (json['correct_order'] as List<dynamic>?)
                  ?.map((o) => o as int)
                  .toList() ??
              [],
        );

      case 'matching':
        return QuizMatchingContent(
          leftItems: (json['left'] as List<dynamic>?)
                  ?.map((l) => l as String)
                  .toList() ??
              [],
          rightItems: (json['right'] as List<dynamic>?)
                  ?.map((r) => r as String)
                  .toList() ??
              [],
          correctPairs: _parsePairs(json['correct_pairs']),
        );

      case 'who_says_what':
        return WhoSaysWhatContent(
          characters: (json['characters'] as List<dynamic>?)
                  ?.map((c) => c as String)
                  .toList() ??
              [],
          quotes: (json['quotes'] as List<dynamic>?)
                  ?.map((q) => q as String)
                  .toList() ??
              [],
          correctPairs: _parsePairs(json['correct_pairs']),
        );

      default:
        return const MultipleChoiceContent(options: [], correctAnswer: '');
    }
  }

  /// Parse correct_pairs from JSON (`{"0":"1","1":"0"}`) to `Map<int,int>`
  static Map<int, int> _parsePairs(dynamic json) {
    if (json is! Map) return {};
    final result = <int, int>{};
    for (final entry in json.entries) {
      final key = int.tryParse(entry.key.toString());
      final value = int.tryParse(entry.value.toString());
      if (key != null && value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  // ============================================
  // ENTITY → JSON (used by offline cache)
  // ============================================

  static Map<String, dynamic> _contentToJson(
    BookQuizQuestionType type,
    BookQuizQuestionContent content,
  ) {
    switch (type) {
      case BookQuizQuestionType.multipleChoice:
        final mc = content as MultipleChoiceContent;
        return {
          'options': mc.options,
          'correct_answer': mc.correctAnswer,
        };

      case BookQuizQuestionType.fillBlank:
        final fb = content as FillBlankContent;
        return {
          'sentence': fb.sentence,
          'correct_answer': fb.correctAnswer,
          'accept_alternatives': fb.acceptAlternatives,
        };

      case BookQuizQuestionType.eventSequencing:
        final es = content as EventSequencingContent;
        return {
          'events': es.events,
          'correct_order': es.correctOrder,
        };

      case BookQuizQuestionType.matching:
        final m = content as QuizMatchingContent;
        return {
          'left': m.leftItems,
          'right': m.rightItems,
          'correct_pairs': _pairsToJson(m.correctPairs),
        };

      case BookQuizQuestionType.whoSaysWhat:
        final wsw = content as WhoSaysWhatContent;
        return {
          'characters': wsw.characters,
          'quotes': wsw.quotes,
          'correct_pairs': _pairsToJson(wsw.correctPairs),
        };
    }
  }

  /// Convert `Map<int,int>` pairs to JSON format `{"0":"1","1":"0"}`
  static Map<String, String> _pairsToJson(Map<int, int> pairs) {
    return pairs.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}
