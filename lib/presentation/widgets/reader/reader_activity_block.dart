import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/reader_provider.dart';
import '../../providers/teacher_preview_provider.dart';
import '../inline_activities/inline_activities.dart';

/// Widget for rendering an activity content block.
/// Activity is passed directly from parent (loaded with chapter context).
class ReaderActivityBlock extends ConsumerWidget {
  const ReaderActivityBlock({
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

    final isPreview = ref.watch(isTeacherPreviewModeProvider);
    final completedActivities = ref.watch(inlineActivityStateProvider);
    final isCompleted = isPreview || completedActivities.containsKey(activity!.id);
    final wasCorrect = isPreview ? true : completedActivities[activity!.id];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500), // Enforce compact width (was effectively 680)
        child: _buildActivity(
          context,
          ref,
          activity!,
          isCompleted,
          wasCorrect,
        ),
      ),
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
        return InlineTrueFalseActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect) {
            _handleActivityAnswer(ref, activity, isCorrect, []);
          },
        );

      case InlineActivityType.wordTranslation:
        return InlineWordTranslationActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect, wordsLearned) {
            _handleActivityAnswer(ref, activity, isCorrect, wordsLearned);
          },
        );

      case InlineActivityType.findWords:
        return InlineFindWordsActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect, wordsLearned) {
            _handleActivityAnswer(ref, activity, isCorrect, wordsLearned);
          },
        );

      case InlineActivityType.matching:
        return InlineMatchingActivity(
          activity: activity,
          settings: settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect, wordsLearned) {
            _handleActivityAnswer(ref, activity, isCorrect, wordsLearned);
          },
        );
    }
  }

  Future<void> _handleActivityAnswer(
    WidgetRef ref,
    InlineActivity activity,
    bool isCorrect,
    List<String> wordsLearned,
  ) async {
    final xpEarned = isCorrect ? getInlineActivityXP(ref, activity.type) : 0;
    await handleInlineActivityCompletion(
      ref,
      activityId: activity.id,
      isCorrect: isCorrect,
      xpEarned: xpEarned,
      wordsLearned: wordsLearned,
      onComplete: onActivityCompleted,
    );
  }
}
