import 'package:equatable/equatable.dart';

/// Represents a collection of vocabulary words that can be studied together
class WordList extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? level; // A1, A2, B1, B2, C1, C2
  final WordListCategory category;
  final int wordCount;
  final String? coverImageUrl;
  final bool isSystem; // true = admin created, false = user created (story vocab)
  final String? sourceBookId; // for story vocabulary lists
  final DateTime createdAt;
  final DateTime updatedAt;

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
    required this.createdAt,
    required this.updatedAt,
  });

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
        createdAt,
        updatedAt,
      ];
}

/// Categories for organizing word lists
enum WordListCategory {
  commonWords,    // Common Words Level 1, 2, 3...
  gradeLevel,     // Grade 1-12 vocabulary
  testPrep,       // YDS, YÖKDİL, TOEFL, etc.
  thematic,       // Animals, Food, Travel, etc.
  storyVocab,     // Words from stories/books
}

extension WordListCategoryExtension on WordListCategory {
  String get displayName {
    switch (this) {
      case WordListCategory.commonWords:
        return 'Common Words';
      case WordListCategory.gradeLevel:
        return 'Grade Level';
      case WordListCategory.testPrep:
        return 'Test Preparation';
      case WordListCategory.thematic:
        return 'Thematic';
      case WordListCategory.storyVocab:
        return 'Story Vocabulary';
    }
  }

  String get icon {
    switch (this) {
      case WordListCategory.commonWords:
        return '📚';
      case WordListCategory.gradeLevel:
        return '🎓';
      case WordListCategory.testPrep:
        return '📝';
      case WordListCategory.thematic:
        return '🏷️';
      case WordListCategory.storyVocab:
        return '📖';
    }
  }
}

/// Tracks user progress for a specific word list
class UserWordListProgress extends Equatable {
  final String id;
  final String userId;
  final String wordListId;
  final bool phase1Complete; // Learn Vocab
  final bool phase2Complete; // Spelling
  final bool phase3Complete; // Flashcards
  final bool phase4Complete; // Review
  final int? phase4Score;    // Review score (e.g., 18/20)
  final int? phase4Total;    // Total questions in review
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const UserWordListProgress({
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

  /// Overall progress percentage (0.0 - 1.0)
  double get progressPercentage {
    int completed = 0;
    if (phase1Complete) completed++;
    if (phase2Complete) completed++;
    if (phase3Complete) completed++;
    if (phase4Complete) completed++;
    return completed / 4;
  }

  /// Number of completed phases
  int get completedPhases {
    int count = 0;
    if (phase1Complete) count++;
    if (phase2Complete) count++;
    if (phase3Complete) count++;
    if (phase4Complete) count++;
    return count;
  }

  /// Check if all phases are complete
  bool get isFullyComplete => phase1Complete && phase2Complete && phase3Complete && phase4Complete;

  /// Get the next recommended phase (1-4), or null if all complete
  int? get nextPhase {
    if (!phase1Complete) return 1;
    if (!phase2Complete) return 2;
    if (!phase3Complete) return 3;
    if (!phase4Complete) return 4;
    return null;
  }

  UserWordListProgress copyWith({
    String? id,
    String? userId,
    String? wordListId,
    bool? phase1Complete,
    bool? phase2Complete,
    bool? phase3Complete,
    bool? phase4Complete,
    int? phase4Score,
    int? phase4Total,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return UserWordListProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wordListId: wordListId ?? this.wordListId,
      phase1Complete: phase1Complete ?? this.phase1Complete,
      phase2Complete: phase2Complete ?? this.phase2Complete,
      phase3Complete: phase3Complete ?? this.phase3Complete,
      phase4Complete: phase4Complete ?? this.phase4Complete,
      phase4Score: phase4Score ?? this.phase4Score,
      phase4Total: phase4Total ?? this.phase4Total,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        wordListId,
        phase1Complete,
        phase2Complete,
        phase3Complete,
        phase4Complete,
        phase4Score,
        phase4Total,
        startedAt,
        completedAt,
        updatedAt,
      ];
}
