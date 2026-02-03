import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:readeng/presentation/widgets/activities/true_false_activity.dart';
import 'package:readeng/presentation/widgets/activities/word_translation_activity.dart';
import 'package:readeng/presentation/widgets/activities/find_words_activity.dart';
import 'package:readeng/presentation/widgets/activities/activity_wrapper.dart';
import 'package:readeng/domain/entities/activity.dart';
import 'package:readeng/presentation/providers/reader_provider.dart';

/// Activity widgets for Widgetbook
final activityWidgets = [
  // Activity Wrapper
  WidgetbookComponent(
    name: 'ActivityWrapper',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => ActivityWrapper(
          settings: _lightSettings,
          isCompleted: false,
          isCorrect: null,
          child: const Center(
            child: Text('Activity Content Here'),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Completed - Correct',
        builder: (context) => ActivityWrapper(
          settings: _lightSettings,
          isCompleted: true,
          isCorrect: true,
          child: const Center(
            child: Text('Correct Answer!'),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Completed - Wrong',
        builder: (context) => ActivityWrapper(
          settings: _lightSettings,
          isCompleted: true,
          isCorrect: false,
          child: const Center(
            child: Text('Wrong Answer'),
          ),
        ),
      ),
    ],
  ),

  // True/False Activity
  WidgetbookComponent(
    name: 'TrueFalseActivity',
    useCases: [
      WidgetbookUseCase(
        name: 'Light Theme',
        builder: (context) => TrueFalseActivity(
          activity: _trueFalseActivity,
          settings: _lightSettings,
          onAnswer: (isCorrect, xp) {},
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => TrueFalseActivity(
          activity: _trueFalseActivity,
          settings: _darkSettings,
          onAnswer: (isCorrect, xp) {},
        ),
      ),
      WidgetbookUseCase(
        name: 'Completed - Correct',
        builder: (context) => TrueFalseActivity(
          activity: _trueFalseActivity,
          settings: _lightSettings,
          onAnswer: (isCorrect, xp) {},
          isCompleted: true,
          wasCorrect: true,
        ),
      ),
      WidgetbookUseCase(
        name: 'Completed - Wrong',
        builder: (context) => TrueFalseActivity(
          activity: _trueFalseActivity,
          settings: _lightSettings,
          onAnswer: (isCorrect, xp) {},
          isCompleted: true,
          wasCorrect: false,
        ),
      ),
    ],
  ),

  // Word Translation Activity
  WidgetbookComponent(
    name: 'WordTranslationActivity',
    useCases: [
      WidgetbookUseCase(
        name: 'Light Theme',
        builder: (context) => WordTranslationActivity(
          activity: _wordTranslationActivity,
          settings: _lightSettings,
          onAnswer: (isCorrect, xp, words) {},
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => WordTranslationActivity(
          activity: _wordTranslationActivity,
          settings: _darkSettings,
          onAnswer: (isCorrect, xp, words) {},
        ),
      ),
    ],
  ),

  // Find Words Activity
  WidgetbookComponent(
    name: 'FindWordsActivity',
    useCases: [
      WidgetbookUseCase(
        name: 'Light Theme',
        builder: (context) => FindWordsActivity(
          activity: _findWordsActivity,
          settings: _lightSettings,
          onAnswer: (isCorrect, xp, words) {},
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => FindWordsActivity(
          activity: _findWordsActivity,
          settings: _darkSettings,
          onAnswer: (isCorrect, xp, words) {},
        ),
      ),
    ],
  ),
];

// Mock Settings
const _lightSettings = ReaderSettings(
  fontSize: 18,
  lineHeight: 1.6,
  theme: ReaderTheme.light,
  showVocabularyHighlights: true,
);

const _darkSettings = ReaderSettings(
  fontSize: 18,
  lineHeight: 1.6,
  theme: ReaderTheme.dark,
  showVocabularyHighlights: true,
);

// Mock Activities
final _trueFalseActivity = InlineActivity(
  id: 'activity-1',
  type: InlineActivityType.trueFalse,
  afterParagraphIndex: 0,
  xpReward: 10,
  content: const TrueFalseContent(
    statement: 'The cat is sitting on the mat.',
    correctAnswer: true,
  ),
);

final _wordTranslationActivity = InlineActivity(
  id: 'activity-2',
  type: InlineActivityType.wordTranslation,
  afterParagraphIndex: 1,
  xpReward: 15,
  content: const WordTranslationContent(
    word: 'beautiful',
    correctAnswer: 'güzel',
    options: ['güzel', 'çirkin', 'büyük', 'küçük'],
  ),
);

final _findWordsActivity = InlineActivity(
  id: 'activity-3',
  type: InlineActivityType.findWords,
  afterParagraphIndex: 2,
  xpReward: 20,
  content: const FindWordsContent(
    instruction: 'Find the adjectives in the paragraph:',
    options: ['beautiful', 'quickly', 'small', 'ran', 'happy'],
    correctAnswers: ['beautiful', 'small', 'happy'],
  ),
);
