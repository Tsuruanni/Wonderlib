import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/usecases/activity/get_completed_inline_activities_usecase.dart';
import '../../domain/usecases/activity/save_inline_activity_result_usecase.dart';
import '../../domain/usecases/user/update_user_usecase.dart';
import '../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

/// Reader theme options
enum ReaderTheme {
  light(
    background: Color(0xFFFFFFFF),
    text: Color(0xFF1E293B),
    name: 'Light',
  ),
  sepia(
    background: Color(0xFFF5E6D3),
    text: Color(0xFF5C4033),
    name: 'Sepia',
  ),
  dark(
    background: Color(0xFF1E293B),
    text: Color(0xFFF1F5F9),
    name: 'Dark',
  );

  final Color background;
  final Color text;
  final String name;

  const ReaderTheme({
    required this.background,
    required this.text,
    required this.name,
  });
}

/// Reader settings state
class ReaderSettings {

  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.theme = ReaderTheme.light,
    this.showVocabularyHighlights = true,
  });
  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;
  final bool showVocabularyHighlights;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderTheme? theme,
    bool? showVocabularyHighlights,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
      showVocabularyHighlights: showVocabularyHighlights ?? this.showVocabularyHighlights,
    );
  }
}

/// Reader settings notifier - loads from and saves to user profile
class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {

  ReaderSettingsNotifier(this._ref) : super(const ReaderSettings()) {
    _loadFromProfile();
  }
  final Ref _ref;

  void _loadFromProfile() {
    final user = _ref.read(authStateChangesProvider).valueOrNull;
    if (user != null && user.settings.isNotEmpty) {
      final readerSettings = user.settings['reader'] as Map<String, dynamic>?;
      if (readerSettings != null) {
        state = ReaderSettings(
          fontSize: (readerSettings['fontSize'] as num?)?.toDouble() ?? 18,
          lineHeight: (readerSettings['lineHeight'] as num?)?.toDouble() ?? 1.6,
          theme: _parseTheme(readerSettings['theme'] as String?),
          showVocabularyHighlights: readerSettings['showVocabularyHighlights'] as bool? ?? true,
        );
      }
    }
  }

  ReaderTheme _parseTheme(String? theme) {
    switch (theme) {
      case 'sepia':
        return ReaderTheme.sepia;
      case 'dark':
        return ReaderTheme.dark;
      default:
        return ReaderTheme.light;
    }
  }

  Future<void> _saveToProfile() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final user = _ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) return;

    final updatedSettings = Map<String, dynamic>.from(user.settings);
    updatedSettings['reader'] = {
      'fontSize': state.fontSize,
      'lineHeight': state.lineHeight,
      'theme': state.theme.name,
      'showVocabularyHighlights': state.showVocabularyHighlights,
    };

    final updateUserUseCase = _ref.read(updateUserUseCaseProvider);
    await updateUserUseCase(UpdateUserParams(user: user.copyWith(settings: updatedSettings)));
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(14, 28));
    _saveToProfile();
  }

  void setLineHeight(double height) {
    state = state.copyWith(lineHeight: height.clamp(1.2, 2.0));
    _saveToProfile();
  }

  void setTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
    _saveToProfile();
  }

  void toggleVocabularyHighlights() {
    state = state.copyWith(
      showVocabularyHighlights: !state.showVocabularyHighlights,
    );
    _saveToProfile();
  }
}

/// Reader settings provider
final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier(ref);
});

/// Currently selected vocabulary word (for popup)
final selectedVocabularyProvider = StateProvider<ChapterVocabulary?>((ref) => null);

/// Vocabulary popup position
final vocabularyPopupPositionProvider = StateProvider<Offset?>((ref) => null);

/// Reading timer state (in seconds)
class ReadingTimerNotifier extends StateNotifier<int> {
  ReadingTimerNotifier() : super(0);

  void tick() {
    state = state + 1;
  }

  void reset() {
    state = 0;
  }
}

/// Reading timer provider
final readingTimerProvider =
    StateNotifierProvider.autoDispose<ReadingTimerNotifier, int>((ref) {
  return ReadingTimerNotifier();
});

/// Current scroll progress (0.0 to 1.0)
final scrollProgressProvider = StateProvider<double>((ref) => 0.0);

// ============================================
// INLINE ACTIVITY STATE
// ============================================

/// Completed inline activities (activityId -> result)
class InlineActivityStateNotifier extends StateNotifier<Map<String, bool>> {
  InlineActivityStateNotifier() : super({});

  void markCompleted(String activityId, bool isCorrect) {
    state = {...state, activityId: isCorrect};
  }

  void loadFromList(List<String> completedIds) {
    final newState = <String, bool>{};
    for (final id in completedIds) {
      newState[id] = true; // We don't know if it was correct, assume true
    }
    state = newState;
  }

  bool isCompleted(String activityId) {
    return state.containsKey(activityId);
  }

  bool? getResult(String activityId) {
    return state[activityId];
  }

  void reset() {
    state = {};
  }
}

/// Provider for tracking completed inline activities
final inlineActivityStateProvider =
    StateNotifierProvider.autoDispose<InlineActivityStateNotifier, Map<String, bool>>((ref) {
  return InlineActivityStateNotifier();
});

/// Loads completed inline activities for a chapter from database
final completedInlineActivitiesProvider =
    FutureProvider.family<List<String>, String>((ref, chapterId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getCompletedInlineActivitiesUseCaseProvider);
  final result = await useCase(GetCompletedInlineActivitiesParams(
    userId: userId,
    chapterId: chapterId,
  ),);

  return result.fold(
    (failure) => [],
    (ids) => ids,
  );
});

/// Total XP earned in current reading session
class SessionXPNotifier extends StateNotifier<int> {
  SessionXPNotifier() : super(0);

  void addXP(int amount) {
    state = state + amount;
  }

  void reset() {
    state = 0;
  }
}

/// Provider for session XP
final sessionXPProvider =
    StateNotifierProvider.autoDispose<SessionXPNotifier, int>((ref) {
  return SessionXPNotifier();
});

/// Words learned in current session (to add to vocabulary)
class LearnedWordsNotifier extends StateNotifier<List<String>> {
  LearnedWordsNotifier() : super([]);

  void addWords(List<String> words) {
    final newWords = words.where((w) => !state.contains(w)).toList();
    if (newWords.isNotEmpty) {
      state = [...state, ...newWords];
    }
  }

  void reset() {
    state = [];
  }
}

/// Provider for words learned in session
final learnedWordsProvider =
    StateNotifierProvider.autoDispose<LearnedWordsNotifier, List<String>>((ref) {
  return LearnedWordsNotifier();
});

// ============================================
// CHAPTER PROGRESS (ACTIVITY-BASED)
// ============================================

/// Total number of activities in current chapter
final totalActivitiesProvider = StateProvider<int>((ref) => 0);

/// Activity-based progress (0.0 to 1.0)
/// Progress = completed activities / total activities
final activityProgressProvider = Provider<double>((ref) {
  final completedActivities = ref.watch(inlineActivityStateProvider);
  final totalActivities = ref.watch(totalActivitiesProvider);

  if (totalActivities == 0) return 0.0;

  return (completedActivities.length / totalActivities).clamp(0.0, 1.0);
});

/// Whether all activities in the chapter are completed
/// Note: If there are no activities, chapter is considered complete
final isChapterCompleteProvider = Provider<bool>((ref) {
  final completedActivities = ref.watch(inlineActivityStateProvider);
  final totalActivities = ref.watch(totalActivitiesProvider);

  // If no activities, chapter is complete (can proceed to next)
  if (totalActivities == 0) return true;

  return completedActivities.length >= totalActivities;
});

// ============================================
// CURRENT CHAPTER TRACKING
// ============================================

/// Current chapter ID for word audio playback context
final currentChapterIdProvider = StateProvider<String?>((ref) => null);

/// Whether the current chapter has finished initial loading (activities loaded from DB)
/// Used to prevent auto-play before we know if user has existing progress
final chapterInitializedProvider = StateProvider<bool>((ref) => false);

// ============================================
// INLINE ACTIVITY COMPLETION HANDLER
// ============================================

/// Handles inline activity completion - saves to DB, awards XP, adds words to vocabulary
Future<void> handleInlineActivityCompletion(
  WidgetRef ref, {
  required String activityId,
  required bool isCorrect,
  required int xpEarned,
  required List<String> wordsLearned,
  void Function(bool isCorrect, int xpEarned)? onComplete,
}) async {
  // Check if already completed locally
  final completedActivities = ref.read(inlineActivityStateProvider);
  if (completedActivities.containsKey(activityId)) {
    return;
  }

  // Mark as completed locally
  ref.read(inlineActivityStateProvider.notifier).markCompleted(activityId, isCorrect);

  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  // Save to database
  final useCase = ref.read(saveInlineActivityResultUseCaseProvider);
  final result = await useCase(
    SaveInlineActivityResultParams(
      userId: userId,
      activityId: activityId,
      isCorrect: isCorrect,
      xpEarned: xpEarned,
    ),
  );

  final isNewCompletion = result.fold(
    (failure) => false,
    (isNew) => isNew,
  );

  // Award XP for new completions
  if (isNewCompletion && xpEarned > 0) {
    ref.read(sessionXPProvider.notifier).addXP(xpEarned);
    await ref.read(userControllerProvider.notifier).addXP(xpEarned);
  } else if (isNewCompletion) {
    // Update streak even without XP (wrong answer still counts as daily activity)
    await ref.read(userControllerProvider.notifier).updateStreak();
  }

  // Add words to vocabulary
  if (wordsLearned.isNotEmpty) {
    ref.read(learnedWordsProvider.notifier).addWords(wordsLearned);

    final addWordUseCase = ref.read(addWordToVocabularyUseCaseProvider);
    for (final wordId in wordsLearned) {
      await addWordUseCase(
        AddWordToVocabularyParams(
          userId: userId,
          wordId: wordId,
        ),
      );
    }
  }

  // Notify caller
  onComplete?.call(isCorrect, xpEarned);
}
