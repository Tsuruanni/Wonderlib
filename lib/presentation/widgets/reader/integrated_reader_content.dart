import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/usecases/activity/save_inline_activity_result_usecase.dart';
import '../../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/user_provider.dart';
import '../activities/activities.dart';
import 'paragraph_widget.dart';

/// Integrated reader content with inline activities between paragraphs
/// Content is progressively revealed - activities must be completed to unlock next section
class IntegratedReaderContent extends ConsumerStatefulWidget {
  const IntegratedReaderContent({
    super.key,
    required this.chapter,
    required this.settings,
    required this.onVocabularyTap,
    this.onWordTap,
    this.scrollController,
  });

  final Chapter chapter;
  final ReaderSettings settings;
  final void Function(ChapterVocabulary vocab, Offset position) onVocabularyTap;
  final void Function(String word, Offset position)? onWordTap;
  final ScrollController? scrollController;

  @override
  ConsumerState<IntegratedReaderContent> createState() => _IntegratedReaderContentState();
}

class _IntegratedReaderContentState extends ConsumerState<IntegratedReaderContent> {
  int _previousCompletedCount = 0;

  @override
  Widget build(BuildContext context) {
    final paragraphs = widget.chapter.paragraphs;
    final activitiesAsync = ref.watch(inlineActivitiesProvider(widget.chapter.id));
    final completedActivities = ref.watch(inlineActivityStateProvider);

    // Get inline activities from async state
    final inlineActivities = activitiesAsync.when(
      data: (activities) => activities,
      loading: () => <InlineActivity>[],
      error: (_, __) => <InlineActivity>[],
    );

    // Check if a new activity was just completed to trigger scroll
    final currentCompletedCount = completedActivities.length;
    if (currentCompletedCount > _previousCompletedCount) {
      _previousCompletedCount = currentCompletedCount;
      // Schedule scroll after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToNewContent();
      });
    }

    // Build interleaved list of paragraphs and activities
    final items = _buildInterleavedItems(paragraphs, inlineActivities);

    // Find the first uncompleted activity to determine where to stop
    final visibleItems = <_ContentItem>[];
    for (final item in items) {
      visibleItems.add(item);

      // If this is an uncompleted activity, stop here (show it but nothing after)
      if (item is _ActivityItem && !completedActivities.containsKey(item.activity.id)) {
        break;
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: visibleItems.map((item) {
            if (item is _ParagraphItem) {
              return ParagraphWidget(
                content: item.content,
                vocabulary: widget.chapter.vocabulary,
                settings: widget.settings,
                onVocabularyTap: widget.onVocabularyTap,
                onWordTap: widget.onWordTap,
              );
            } else if (item is _ActivityItem) {
              final activity = item.activity;
              final isCompleted = completedActivities.containsKey(activity.id);
              final wasCorrect = completedActivities[activity.id];

              return _buildActivity(context, activity, isCompleted, wasCorrect);
            }
            return const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }

  void _scrollToNewContent() {
    if (widget.scrollController == null || !widget.scrollController!.hasClients) return;

    final currentPosition = widget.scrollController!.position.pixels;
    final maxScroll = widget.scrollController!.position.maxScrollExtent;

    // Scroll down by 200 pixels or to the end
    final targetPosition = (currentPosition + 200).clamp(0.0, maxScroll);

    widget.scrollController!.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  List<_ContentItem> _buildInterleavedItems(
    List<String> paragraphs,
    List<InlineActivity> activities,
  ) {
    final items = <_ContentItem>[];

    // Create a map of activities by their position
    final activityMap = <int, List<InlineActivity>>{};
    for (final activity in activities) {
      activityMap.putIfAbsent(activity.afterParagraphIndex, () => []);
      activityMap[activity.afterParagraphIndex]!.add(activity);
    }

    for (var i = 0; i < paragraphs.length; i++) {
      // Add paragraph
      items.add(_ParagraphItem(paragraphs[i]));

      // Add activities after this paragraph
      if (activityMap.containsKey(i)) {
        for (final activity in activityMap[i]!) {
          items.add(_ActivityItem(activity));
        }
      }
    }

    return items;
  }

  Widget _buildActivity(
    BuildContext context,
    InlineActivity activity,
    bool isCompleted,
    bool? wasCorrect,
  ) {
    switch (activity.type) {
      case InlineActivityType.trueFalse:
        return TrueFalseActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          onAnswer: (isCorrect, xpEarned) {
            _handleActivityAnswer(activity.id, isCorrect, xpEarned, []);
          },
        );

      case InlineActivityType.wordTranslation:
        return WordTranslationActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          onAnswer: (isCorrect, xpEarned, wordsLearned) {
            _handleActivityAnswer(activity.id, isCorrect, xpEarned, wordsLearned);
          },
        );

      case InlineActivityType.findWords:
        return FindWordsActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          onAnswer: (isCorrect, xpEarned, wordsLearned) {
            _handleActivityAnswer(activity.id, isCorrect, xpEarned, wordsLearned);
          },
        );
    }
  }

  Future<void> _handleActivityAnswer(
    String activityId,
    bool isCorrect,
    int xpEarned,
    List<String> wordsLearned,
  ) async {
    // Layer 1: Quick check local state to prevent double-processing
    final completedActivities = ref.read(inlineActivityStateProvider);
    if (completedActivities.containsKey(activityId)) {
      return; // Already completed locally, skip everything
    }

    // Mark activity as completed in local state
    ref.read(inlineActivityStateProvider.notifier).markCompleted(activityId, isCorrect);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Layer 2: Save to DB and check if this is a NEW completion
    final useCase = ref.read(saveInlineActivityResultUseCaseProvider);
    final result = await useCase(SaveInlineActivityResultParams(
      userId: userId,
      activityId: activityId,
      isCorrect: isCorrect,
      xpEarned: xpEarned,
    ),);

    // Extract whether this is a new completion (prevents duplicate XP)
    final isNewCompletion = result.fold(
      (failure) => false, // On error, don't award XP
      (isNew) => isNew,
    );

    // Only award XP for NEW completions
    if (isNewCompletion && xpEarned > 0) {
      // Update local session XP counter
      ref.read(sessionXPProvider.notifier).addXP(xpEarned);

      // Persist XP to database AND update local state (no page reload)
      await ref.read(userControllerProvider.notifier).addXP(xpEarned);
    } else if (isNewCompletion) {
      // Update streak even without XP (wrong answer still counts as daily activity)
      await ref.read(userControllerProvider.notifier).updateStreak();
    }

    // Add words to learned vocabulary (idempotent - safe to retry)
    if (wordsLearned.isNotEmpty) {
      ref.read(learnedWordsProvider.notifier).addWords(wordsLearned);

      // Persist to vocabulary_progress
      final addWordUseCase = ref.read(addWordToVocabularyUseCaseProvider);
      for (final wordId in wordsLearned) {
        await addWordUseCase(AddWordToVocabularyParams(
          userId: userId,
          wordId: wordId,
        ),);
      }
    }
  }
}

// Helper classes for content items
abstract class _ContentItem {}

class _ParagraphItem extends _ContentItem {
  _ParagraphItem(this.content);
  final String content;
}

class _ActivityItem extends _ContentItem {
  _ActivityItem(this.activity);
  final InlineActivity activity;
}
