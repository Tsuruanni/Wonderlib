import '../../../domain/entities/activity.dart';

/// Model for Activity entity - handles JSON serialization
class ActivityModel {
  final String id;
  final String chapterId;
  final String type;
  final int orderIndex;
  final String? title;
  final String? instructions;
  final List<ActivityQuestionModel> questions;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityModel({
    required this.id,
    required this.chapterId,
    required this.type,
    required this.orderIndex,
    this.title,
    this.instructions,
    this.questions = const [],
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['questions'] as List<dynamic>?;
    final questions = questionsJson
            ?.map((q) => ActivityQuestionModel.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];

    return ActivityModel(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      type: json['type'] as String? ?? 'multiple_choice',
      orderIndex: json['order_index'] as int? ?? 0,
      title: json['title'] as String?,
      instructions: json['instructions'] as String?,
      questions: questions,
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'type': type,
      'order_index': orderIndex,
      'title': title,
      'instructions': instructions,
      'questions': questions.map((q) => q.toJson()).toList(),
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Activity toEntity() {
    return Activity(
      id: id,
      chapterId: chapterId,
      type: _parseActivityType(type),
      orderIndex: orderIndex,
      title: title,
      instructions: instructions,
      questions: questions.map((q) => q.toEntity()).toList(),
      settings: settings,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ActivityModel.fromEntity(Activity entity) {
    return ActivityModel(
      id: entity.id,
      chapterId: entity.chapterId,
      type: _activityTypeToString(entity.type),
      orderIndex: entity.orderIndex,
      title: entity.title,
      instructions: entity.instructions,
      questions: entity.questions.map((q) => ActivityQuestionModel.fromEntity(q)).toList(),
      settings: entity.settings,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  static ActivityType _parseActivityType(String type) {
    switch (type) {
      case 'multiple_choice':
        return ActivityType.multipleChoice;
      case 'true_false':
        return ActivityType.trueFalse;
      case 'matching':
        return ActivityType.matching;
      case 'ordering':
        return ActivityType.ordering;
      case 'fill_blank':
        return ActivityType.fillBlank;
      case 'short_answer':
        return ActivityType.shortAnswer;
      default:
        return ActivityType.multipleChoice;
    }
  }

  static String _activityTypeToString(ActivityType type) {
    switch (type) {
      case ActivityType.multipleChoice:
        return 'multiple_choice';
      case ActivityType.trueFalse:
        return 'true_false';
      case ActivityType.matching:
        return 'matching';
      case ActivityType.ordering:
        return 'ordering';
      case ActivityType.fillBlank:
        return 'fill_blank';
      case ActivityType.shortAnswer:
        return 'short_answer';
    }
  }
}

/// Model for ActivityQuestion entity
class ActivityQuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final dynamic correctAnswer;
  final String? explanation;
  final String? imageUrl;
  final int points;

  const ActivityQuestionModel({
    required this.id,
    required this.question,
    this.options = const [],
    required this.correctAnswer,
    this.explanation,
    this.imageUrl,
    this.points = 1,
  });

  factory ActivityQuestionModel.fromJson(Map<String, dynamic> json) {
    return ActivityQuestionModel(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)?.map((o) => o as String).toList() ?? [],
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'] as String?,
      imageUrl: json['image_url'] as String?,
      points: json['points'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'image_url': imageUrl,
      'points': points,
    };
  }

  ActivityQuestion toEntity() {
    return ActivityQuestion(
      id: id,
      question: question,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation,
      imageUrl: imageUrl,
      points: points,
    );
  }

  factory ActivityQuestionModel.fromEntity(ActivityQuestion entity) {
    return ActivityQuestionModel(
      id: entity.id,
      question: entity.question,
      options: entity.options,
      correctAnswer: entity.correctAnswer,
      explanation: entity.explanation,
      imageUrl: entity.imageUrl,
      points: entity.points,
    );
  }
}
