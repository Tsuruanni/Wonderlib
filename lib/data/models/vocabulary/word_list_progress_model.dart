import '../../../domain/entities/word_list.dart';

/// Model for UserWordListProgress entity - handles JSON serialization
class WordListProgressModel {
  final String id;
  final String userId;
  final String wordListId;
  final bool phase1Complete;
  final bool phase2Complete;
  final bool phase3Complete;
  final bool phase4Complete;
  final int? phase4Score;
  final int? phase4Total;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const WordListProgressModel({
    required this.id,
    required this.userId,
    required this.wordListId,
    this.phase1Complete = false,
    this.phase2Complete = false,
    this.phase3Complete = false,
    this.phase4Complete = false,
    this.phase4Score,
    this.phase4Total,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
  });

  factory WordListProgressModel.fromJson(Map<String, dynamic> json) {
    return WordListProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordListId: json['word_list_id'] as String,
      phase1Complete: json['phase1_complete'] as bool? ?? false,
      phase2Complete: json['phase2_complete'] as bool? ?? false,
      phase3Complete: json['phase3_complete'] as bool? ?? false,
      phase4Complete: json['phase4_complete'] as bool? ?? false,
      phase4Score: json['phase4_score'] as int?,
      phase4Total: json['phase4_total'] as int?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'word_list_id': wordListId,
      'phase1_complete': phase1Complete,
      'phase2_complete': phase2Complete,
      'phase3_complete': phase3Complete,
      'phase4_complete': phase4Complete,
      'phase4_score': phase4Score,
      'phase4_total': phase4Total,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts to JSON for upsert (without ID)
  Map<String, dynamic> toUpsertJson() {
    return {
      'user_id': userId,
      'word_list_id': wordListId,
      'phase1_complete': phase1Complete,
      'phase2_complete': phase2Complete,
      'phase3_complete': phase3Complete,
      'phase4_complete': phase4Complete,
      'phase4_score': phase4Score,
      'phase4_total': phase4Total,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserWordListProgress toEntity() {
    return UserWordListProgress(
      id: id,
      userId: userId,
      wordListId: wordListId,
      phase1Complete: phase1Complete,
      phase2Complete: phase2Complete,
      phase3Complete: phase3Complete,
      phase4Complete: phase4Complete,
      phase4Score: phase4Score,
      phase4Total: phase4Total,
      startedAt: startedAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
    );
  }

  factory WordListProgressModel.fromEntity(UserWordListProgress entity) {
    return WordListProgressModel(
      id: entity.id,
      userId: entity.userId,
      wordListId: entity.wordListId,
      phase1Complete: entity.phase1Complete,
      phase2Complete: entity.phase2Complete,
      phase3Complete: entity.phase3Complete,
      phase4Complete: entity.phase4Complete,
      phase4Score: entity.phase4Score,
      phase4Total: entity.phase4Total,
      startedAt: entity.startedAt,
      completedAt: entity.completedAt,
      updatedAt: entity.updatedAt,
    );
  }
}
