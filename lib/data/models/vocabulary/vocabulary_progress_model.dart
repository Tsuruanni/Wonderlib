import '../../../domain/entities/vocabulary.dart';

/// Model for VocabularyProgress entity - handles JSON serialization
class VocabularyProgressModel {

  const VocabularyProgressModel({
    required this.id,
    required this.userId,
    required this.wordId,
    this.status = 'new_word',
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.nextReviewAt,
    this.lastReviewedAt,
    required this.createdAt,
  });

  factory VocabularyProgressModel.fromJson(Map<String, dynamic> json) {
    return VocabularyProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordId: json['word_id'] as String,
      status: json['status'] as String? ?? 'new_word',
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: json['interval_days'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReviewAt: json['next_review_at'] != null
          ? DateTime.parse(json['next_review_at'] as String)
          : null,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory VocabularyProgressModel.fromEntity(VocabularyProgress entity) {
    return VocabularyProgressModel(
      id: entity.id,
      userId: entity.userId,
      wordId: entity.wordId,
      status: statusToString(entity.status),
      easeFactor: entity.easeFactor,
      intervalDays: entity.intervalDays,
      repetitions: entity.repetitions,
      nextReviewAt: entity.nextReviewAt,
      lastReviewedAt: entity.lastReviewedAt,
      createdAt: entity.createdAt,
    );
  }
  final String id;
  final String userId;
  final String wordId;
  final String status;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'word_id': wordId,
      'status': status,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'next_review_at': nextReviewAt?.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converts to JSON for insert/update (without ID for auto-generation)
  Map<String, dynamic> toUpsertJson() {
    return {
      'user_id': userId,
      'word_id': wordId,
      'status': status,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'next_review_at': nextReviewAt?.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    };
  }

  VocabularyProgress toEntity() {
    return VocabularyProgress(
      id: id,
      userId: userId,
      wordId: wordId,
      status: _parseStatus(status),
      easeFactor: easeFactor,
      intervalDays: intervalDays,
      repetitions: repetitions,
      nextReviewAt: nextReviewAt,
      lastReviewedAt: lastReviewedAt,
      createdAt: createdAt,
    );
  }

  static VocabularyStatus _parseStatus(String status) {
    switch (status) {
      case 'learning':
        return VocabularyStatus.learning;
      case 'reviewing':
        return VocabularyStatus.reviewing;
      case 'mastered':
        return VocabularyStatus.mastered;
      default:
        return VocabularyStatus.newWord;
    }
  }

  static String statusToString(VocabularyStatus status) {
    switch (status) {
      case VocabularyStatus.newWord:
        return 'new_word';
      case VocabularyStatus.learning:
        return 'learning';
      case VocabularyStatus.reviewing:
        return 'reviewing';
      case VocabularyStatus.mastered:
        return 'mastered';
    }
  }
}
