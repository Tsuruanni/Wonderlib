import 'package:flutter/material.dart';

/// Difficulty levels for games
enum GameDifficulty {
  easy(multiplier: 1.0, label: 'Easy'),
  medium(multiplier: 1.5, label: 'Medium'),
  hard(multiplier: 2.0, label: 'Hard'),
  expert(multiplier: 3.0, label: 'Expert');

  final double multiplier;
  final String label;

  const GameDifficulty({required this.multiplier, required this.label});
}

/// Base configuration for all games
abstract class GameConfig {
  /// Time limit for the game (null = no limit)
  Duration? get timeLimit;

  /// Primary theme color
  Color get themeColor;

  /// Difficulty level
  GameDifficulty get difficulty;

  /// XP reward multiplier based on difficulty
  double get xpMultiplier => difficulty.multiplier;

  /// Whether to show hints
  bool get showHints;

  /// Whether to allow skipping
  bool get allowSkip;

  /// Sound effects enabled
  bool get soundEnabled;

  /// Vibration feedback enabled
  bool get vibrationEnabled;
}

/// Configuration for vocabulary/word-based games
class VocabularyGameConfig implements GameConfig {
  @override
  final Duration? timeLimit;

  @override
  final Color themeColor;

  @override
  final GameDifficulty difficulty;

  @override
  final bool showHints;

  @override
  final bool allowSkip;

  @override
  final bool soundEnabled;

  @override
  final bool vibrationEnabled;

  /// List of words to practice
  final List<String> wordIds;

  /// Number of options for multiple choice
  final int optionCount;

  /// Whether to shuffle word order
  final bool shuffleWords;

  /// Minimum correct answers to pass
  final int? minimumCorrect;

  const VocabularyGameConfig({
    this.timeLimit = const Duration(seconds: 60),
    this.themeColor = Colors.purple,
    this.difficulty = GameDifficulty.medium,
    this.showHints = true,
    this.allowSkip = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    required this.wordIds,
    this.optionCount = 4,
    this.shuffleWords = true,
    this.minimumCorrect,
  });

  @override
  double get xpMultiplier => difficulty.multiplier;

  /// Create a copy with modified values
  VocabularyGameConfig copyWith({
    Duration? timeLimit,
    Color? themeColor,
    GameDifficulty? difficulty,
    bool? showHints,
    bool? allowSkip,
    bool? soundEnabled,
    bool? vibrationEnabled,
    List<String>? wordIds,
    int? optionCount,
    bool? shuffleWords,
    int? minimumCorrect,
  }) {
    return VocabularyGameConfig(
      timeLimit: timeLimit ?? this.timeLimit,
      themeColor: themeColor ?? this.themeColor,
      difficulty: difficulty ?? this.difficulty,
      showHints: showHints ?? this.showHints,
      allowSkip: allowSkip ?? this.allowSkip,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      wordIds: wordIds ?? this.wordIds,
      optionCount: optionCount ?? this.optionCount,
      shuffleWords: shuffleWords ?? this.shuffleWords,
      minimumCorrect: minimumCorrect ?? this.minimumCorrect,
    );
  }
}

/// Configuration for reading comprehension activities
class ReadingActivityConfig implements GameConfig {
  @override
  final Duration? timeLimit;

  @override
  final Color themeColor;

  @override
  final GameDifficulty difficulty;

  @override
  final bool showHints;

  @override
  final bool allowSkip;

  @override
  final bool soundEnabled;

  @override
  final bool vibrationEnabled;

  /// Chapter ID for the activity
  final String chapterId;

  /// Activity IDs to include
  final List<String> activityIds;

  /// Whether to randomize question order
  final bool randomizeQuestions;

  /// Passing score percentage (0-100)
  final int passingScore;

  const ReadingActivityConfig({
    this.timeLimit,
    this.themeColor = Colors.blue,
    this.difficulty = GameDifficulty.medium,
    this.showHints = true,
    this.allowSkip = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    required this.chapterId,
    required this.activityIds,
    this.randomizeQuestions = false,
    this.passingScore = 70,
  });

  @override
  double get xpMultiplier => difficulty.multiplier;

  ReadingActivityConfig copyWith({
    Duration? timeLimit,
    Color? themeColor,
    GameDifficulty? difficulty,
    bool? showHints,
    bool? allowSkip,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? chapterId,
    List<String>? activityIds,
    bool? randomizeQuestions,
    int? passingScore,
  }) {
    return ReadingActivityConfig(
      timeLimit: timeLimit ?? this.timeLimit,
      themeColor: themeColor ?? this.themeColor,
      difficulty: difficulty ?? this.difficulty,
      showHints: showHints ?? this.showHints,
      allowSkip: allowSkip ?? this.allowSkip,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      chapterId: chapterId ?? this.chapterId,
      activityIds: activityIds ?? this.activityIds,
      randomizeQuestions: randomizeQuestions ?? this.randomizeQuestions,
      passingScore: passingScore ?? this.passingScore,
    );
  }
}

/// Configuration for word list practice games
class WordListGameConfig implements GameConfig {
  @override
  final Duration? timeLimit;

  @override
  final Color themeColor;

  @override
  final GameDifficulty difficulty;

  @override
  final bool showHints;

  @override
  final bool allowSkip;

  @override
  final bool soundEnabled;

  @override
  final bool vibrationEnabled;

  /// Word list ID
  final String wordListId;

  /// Current phase (1-4 for spaced repetition)
  final int phase;

  /// Number of words per session
  final int wordsPerSession;

  /// Show word in context sentence
  final bool showContext;

  /// Enable text-to-speech
  final bool enableTTS;

  const WordListGameConfig({
    this.timeLimit,
    this.themeColor = Colors.teal,
    this.difficulty = GameDifficulty.medium,
    this.showHints = true,
    this.allowSkip = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    required this.wordListId,
    this.phase = 1,
    this.wordsPerSession = 10,
    this.showContext = true,
    this.enableTTS = true,
  });

  @override
  double get xpMultiplier => difficulty.multiplier * (phase * 0.5);

  WordListGameConfig copyWith({
    Duration? timeLimit,
    Color? themeColor,
    GameDifficulty? difficulty,
    bool? showHints,
    bool? allowSkip,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? wordListId,
    int? phase,
    int? wordsPerSession,
    bool? showContext,
    bool? enableTTS,
  }) {
    return WordListGameConfig(
      timeLimit: timeLimit ?? this.timeLimit,
      themeColor: themeColor ?? this.themeColor,
      difficulty: difficulty ?? this.difficulty,
      showHints: showHints ?? this.showHints,
      allowSkip: allowSkip ?? this.allowSkip,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      wordListId: wordListId ?? this.wordListId,
      phase: phase ?? this.phase,
      wordsPerSession: wordsPerSession ?? this.wordsPerSession,
      showContext: showContext ?? this.showContext,
      enableTTS: enableTTS ?? this.enableTTS,
    );
  }
}

/// Preset configurations for quick game setup
class GamePresets {
  GamePresets._();

  /// Quick vocabulary review (30 seconds, easy)
  static VocabularyGameConfig quickVocabularyReview(List<String> wordIds) {
    return VocabularyGameConfig(
      wordIds: wordIds,
      timeLimit: const Duration(seconds: 30),
      difficulty: GameDifficulty.easy,
      optionCount: 3,
      showHints: true,
    );
  }

  /// Timed vocabulary challenge (60 seconds, hard)
  static VocabularyGameConfig timedVocabularyChallenge(List<String> wordIds) {
    return VocabularyGameConfig(
      wordIds: wordIds,
      timeLimit: const Duration(seconds: 60),
      difficulty: GameDifficulty.hard,
      optionCount: 4,
      showHints: false,
      allowSkip: false,
    );
  }

  /// Relaxed practice (no time limit, easy)
  static VocabularyGameConfig relaxedPractice(List<String> wordIds) {
    return VocabularyGameConfig(
      wordIds: wordIds,
      timeLimit: null,
      difficulty: GameDifficulty.easy,
      optionCount: 4,
      showHints: true,
      allowSkip: true,
    );
  }

  /// Standard word list session
  static WordListGameConfig standardWordListSession({
    required String wordListId,
    int phase = 1,
  }) {
    return WordListGameConfig(
      wordListId: wordListId,
      phase: phase,
      wordsPerSession: 10,
      difficulty: GameDifficulty.medium,
    );
  }

  /// Intensive word list session (more words, harder)
  static WordListGameConfig intensiveWordListSession({
    required String wordListId,
    int phase = 1,
  }) {
    return WordListGameConfig(
      wordListId: wordListId,
      phase: phase,
      wordsPerSession: 20,
      difficulty: GameDifficulty.hard,
      timeLimit: const Duration(minutes: 5),
    );
  }
}
