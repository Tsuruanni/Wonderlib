import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../../domain/usecases/activity/save_inline_activity_result_usecase.dart';
import '../../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/user_provider.dart';
import '../activities/activities.dart';

/// Widget for rendering an activity content block.
/// Activity is passed directly from parent (loaded with chapter context).
class ActivityBlockWidget extends ConsumerWidget {
  const ActivityBlockWidget({
    super.key,
    required this.block,
    required this.settings,
    this.activity,
    this.onActivityCompleted,
  });

  final ContentBlock block;
  final ReaderSettings settings;
  final InlineActivity? activity;
  final void Function(bool isCorrect, int xpEarned)? onActivityCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activity == null) {
      return _buildErrorState('Activity not found');
    }

    final completedActivities = ref.watch(inlineActivityStateProvider);
    final isCompleted = completedActivities.containsKey(activity!.id);
    final wasCorrect = completedActivities[activity!.id];

    return _buildActivity(
      context,
      ref,
      activity!,
      isCompleted,
      wasCorrect,
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load activity',
              style: TextStyle(
                color: settings.theme.text.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity(
    BuildContext context,
    WidgetRef ref,
    InlineActivity activity,
    bool isCompleted,
    bool? wasCorrect,
  ) {
    switch (activity.type) {
      case InlineActivityType.trueFalse:
        return TrueFalseActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          onAnswer: (isCorrect, xpEarned) {
            _handleActivityAnswer(ref, activity.id, isCorrect, xpEarned, []);
          },
        );

      case InlineActivityType.wordTranslation:
        return WordTranslationActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          onAnswer: (isCorrect, xpEarned, wordsLearned) {
            _handleActivityAnswer(ref, activity.id, isCorrect, xpEarned, wordsLearned);
          },
        );

      case InlineActivityType.findWords:
        return FindWordsActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          onAnswer: (isCorrect, xpEarned, wordsLearned) {
            _handleActivityAnswer(ref, activity.id, isCorrect, xpEarned, wordsLearned);
          },
        );
    }
  }

  Future<void> _handleActivityAnswer(
    WidgetRef ref,
    String activityId,
    bool isCorrect,
    int xpEarned,
    List<String> wordsLearned,
  ) async {
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

    // Notify parent
    onActivityCompleted?.call(isCorrect, xpEarned);
  }
}
