import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/activity_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/teacher_preview_provider.dart';
import '../inline_activities/inline_activities.dart';
import 'reader_paragraph.dart';

/// Integrated reader content with inline activities between paragraphs
/// Content is progressively revealed - activities must be completed to unlock next section
class ReaderLegacyContent extends ConsumerStatefulWidget {
  const ReaderLegacyContent({
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
  ConsumerState<ReaderLegacyContent> createState() => _ReaderLegacyContentState();
}

class _ReaderLegacyContentState extends ConsumerState<ReaderLegacyContent> {
  int _previousCompletedCount = 0;

  @override
  Widget build(BuildContext context) {
    final paragraphs = widget.chapter.paragraphs;
    final activitiesAsync = ref.watch(inlineActivitiesProvider(widget.chapter.id));
    final completedActivities = ref.watch(inlineActivityStateProvider);
    final isPreview = ref.watch(isTeacherPreviewModeProvider);

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

    // Find the first uncompleted activity to determine where to stop.
    // Teacher preview mode reveals everything regardless of completion.
    final visibleItems = <_ContentItem>[];
    for (final item in items) {
      visibleItems.add(item);

      // If this is an uncompleted activity, stop here (show it but nothing after)
      if (!isPreview &&
          item is _ActivityItem &&
          !completedActivities.containsKey(item.activity.id)) {
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
              return ReaderParagraph(
                content: item.content,
                vocabulary: widget.chapter.vocabulary,
                settings: widget.settings,
                onVocabularyTap: widget.onVocabularyTap,
                onWordTap: widget.onWordTap,
              );
            } else if (item is _ActivityItem) {
              final activity = item.activity;
              final isCompleted = isPreview ||
                  completedActivities.containsKey(activity.id);
              final wasCorrect = isPreview
                  ? true
                  : completedActivities[activity.id];

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
        return InlineTrueFalseActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect) {
            _handleActivityAnswer(activity, isCorrect, []);
          },
        );

      case InlineActivityType.wordTranslation:
        return InlineWordTranslationActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect, wordsLearned) {
            _handleActivityAnswer(activity, isCorrect, wordsLearned);
          },
        );

      case InlineActivityType.findWords:
        return InlineFindWordsActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect, wordsLearned) {
            _handleActivityAnswer(activity, isCorrect, wordsLearned);
          },
        );

      case InlineActivityType.matching:
        return InlineMatchingActivity(
          activity: activity,
          settings: widget.settings,
          isCompleted: isCompleted,
          wasCorrect: wasCorrect,
          xpValue: getInlineActivityXP(ref, activity.type),
          onAnswer: (isCorrect, wordsLearned) {
            _handleActivityAnswer(activity, isCorrect, wordsLearned);
          },
        );
    }
  }

  void _handleActivityAnswer(
    InlineActivity activity,
    bool isCorrect,
    List<String> wordsLearned,
  ) {
    final xpEarned = isCorrect ? getInlineActivityXP(ref, activity.type) : 0;
    handleInlineActivityCompletion(
      ref,
      activityId: activity.id,
      isCorrect: isCorrect,
      xpEarned: xpEarned,
      wordsLearned: wordsLearned,
    );
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
