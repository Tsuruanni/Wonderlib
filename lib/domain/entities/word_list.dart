import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

export 'package:owlio_shared/src/enums/word_list_category.dart';

/// Represents a collection of vocabulary words that can be studied together
class WordList extends Equatable {

  const WordList({
    required this.id,
    required this.name,
    required this.description,
    this.level,
    required this.category,
    required this.wordCount,
    this.coverImageUrl,
    this.isSystem = true,
    this.sourceBookId,
    this.unitId,
    this.orderInUnit,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String description;
  final String? level; // A1, A2, B1, B2, C1, C2
  final WordListCategory category;
  final int wordCount;
  final String? coverImageUrl;
  final bool isSystem; // true = admin created, false = user created (story vocab)
  final String? sourceBookId; // for story vocabulary lists
  final String? unitId; // FK to vocabulary_units (null = not in learning path)
  final int? orderInUnit; // Row position within unit (same value = same row)
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        level,
        category,
        wordCount,
        coverImageUrl,
        isSystem,
        sourceBookId,
        unitId,
        orderInUnit,
        createdAt,
        updatedAt,
      ];
}

/// Tracks user progress for a specific word list (session-based)
class UserWordListProgress extends Equatable {

  const UserWordListProgress({
    required this.id,
    required this.userId,
    required this.wordListId,
    this.bestScore,
    this.bestAccuracy,
    this.totalSessions = 0,
    this.lastSessionAt,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String wordListId;
  final int? bestScore;          // Highest XP in a single session
  final double? bestAccuracy;    // Highest accuracy % achieved
  final int totalSessions;       // Number of completed sessions
  final DateTime? lastSessionAt; // When the last session was completed
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  /// Whether the user has completed at least one session
  bool get isComplete => completedAt != null;

  /// Star rating: 3 stars for ≥90%, 2 for ≥70%, 1 for ≥50%, 0 otherwise
  int get starCount {
    if (bestAccuracy == null) return 0;
    if (bestAccuracy! >= 90) return 3;
    if (bestAccuracy! >= 70) return 2;
    if (bestAccuracy! >= 50) return 1;
    return 0;
  }

  UserWordListProgress copyWith({
    String? id,
    String? userId,
    String? wordListId,
    int? bestScore,
    double? bestAccuracy,
    int? totalSessions,
    DateTime? lastSessionAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return UserWordListProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wordListId: wordListId ?? this.wordListId,
      bestScore: bestScore ?? this.bestScore,
      bestAccuracy: bestAccuracy ?? this.bestAccuracy,
      totalSessions: totalSessions ?? this.totalSessions,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, wordListId, bestScore, bestAccuracy,
        totalSessions, lastSessionAt, startedAt, completedAt, updatedAt,
      ];
}
