import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chapter.dart';

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
  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;
  final bool showVocabularyHighlights;

  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.theme = ReaderTheme.light,
    this.showVocabularyHighlights = true,
  });

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

/// Reader settings notifier
class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings());

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(14, 28));
  }

  void setLineHeight(double height) {
    state = state.copyWith(lineHeight: height.clamp(1.2, 2.0));
  }

  void setTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
  }

  void toggleVocabularyHighlights() {
    state = state.copyWith(
      showVocabularyHighlights: !state.showVocabularyHighlights,
    );
  }
}

/// Reader settings provider
final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier();
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
    StateNotifierProvider<ReadingTimerNotifier, int>((ref) {
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
    StateNotifierProvider<InlineActivityStateNotifier, Map<String, bool>>((ref) {
  return InlineActivityStateNotifier();
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
    StateNotifierProvider<SessionXPNotifier, int>((ref) {
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
    StateNotifierProvider<LearnedWordsNotifier, List<String>>((ref) {
  return LearnedWordsNotifier();
});
