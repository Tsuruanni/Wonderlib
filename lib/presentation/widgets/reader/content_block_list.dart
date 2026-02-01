import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/activity_provider.dart';
import '../../providers/content_block_provider.dart';
import '../../providers/reader_provider.dart';
import 'activity_block_widget.dart';
import 'image_block_widget.dart';
import 'text_block_widget.dart';

/// Displays a list of content blocks for a chapter.
/// Handles progressive reveal - activities must be completed to unlock next content.
class ContentBlockList extends ConsumerStatefulWidget {
  const ContentBlockList({
    super.key,
    required this.chapter,
    required this.settings,
    required this.onVocabularyTap,
    this.scrollController,
  });

  final Chapter chapter;
  final ReaderSettings settings;
  final void Function(ChapterVocabulary vocab, Offset position) onVocabularyTap;
  final ScrollController? scrollController;

  @override
  ConsumerState<ContentBlockList> createState() => _ContentBlockListState();
}

class _ContentBlockListState extends ConsumerState<ContentBlockList> {
  int _previousCompletedCount = 0;

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(contentBlocksProvider(widget.chapter.id));
    final inlineActivitiesAsync = ref.watch(inlineActivitiesProvider(widget.chapter.id));
    final completedActivities = ref.watch(inlineActivityStateProvider);

    return blocksAsync.when(
      data: (blocks) {
        final inlineActivities = inlineActivitiesAsync.maybeWhen(
          data: (activities) => activities,
          orElse: () => <InlineActivity>[],
        );

        // Build activity map by ID for quick lookup
        final activityMap = <String, InlineActivity>{};
        for (final activity in inlineActivities) {
          activityMap[activity.id] = activity;
        }

        // Check for new completions to trigger scroll
        final currentCompletedCount = completedActivities.length;
        if (currentCompletedCount > _previousCompletedCount) {
          _previousCompletedCount = currentCompletedCount;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToNewContent();
          });
        }

        // Build visible blocks (stop at first uncompleted activity)
        final visibleBlocks = _getVisibleBlocks(blocks, activityMap, completedActivities);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: visibleBlocks.map((block) {
                return _buildBlockWidget(block, activityMap);
              }).toList(),
            ),
          ),
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(error.toString()),
    );
  }

  List<ContentBlock> _getVisibleBlocks(
    List<ContentBlock> blocks,
    Map<String, InlineActivity> activityMap,
    Map<String, bool> completedActivities,
  ) {
    final visibleBlocks = <ContentBlock>[];

    for (final block in blocks) {
      visibleBlocks.add(block);

      // If this is an activity block and it's not completed, stop here
      if (block.isActivityBlock && block.activityId != null) {
        if (!completedActivities.containsKey(block.activityId)) {
          break;
        }
      }
    }

    return visibleBlocks;
  }

  Widget _buildBlockWidget(
    ContentBlock block,
    Map<String, InlineActivity> activityMap,
  ) {
    switch (block.type) {
      case ContentBlockType.text:
        return TextBlockWidget(
          block: block,
          settings: widget.settings,
          vocabulary: widget.chapter.vocabulary,
          onVocabularyTap: widget.onVocabularyTap,
        );

      case ContentBlockType.image:
        return ImageBlockWidget(
          block: block,
          settings: widget.settings,
        );

      case ContentBlockType.audio:
        // Standalone audio blocks (podcast-style) - render as text with audio
        return TextBlockWidget(
          block: block,
          settings: widget.settings,
          vocabulary: widget.chapter.vocabulary,
          onVocabularyTap: widget.onVocabularyTap,
        );

      case ContentBlockType.activity:
        final activity = block.activityId != null
            ? activityMap[block.activityId]
            : null;
        return ActivityBlockWidget(
          block: block,
          settings: widget.settings,
          activity: activity,
          onActivityCompleted: (isCorrect, xpEarned) {
            // Scroll handled by completion count check above
          },
        );
    }
  }

  void _scrollToNewContent() {
    if (widget.scrollController == null || !widget.scrollController!.hasClients) {
      return;
    }

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

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.settings.theme.text.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: widget.settings.theme.text.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load content',
              style: TextStyle(
                color: widget.settings.theme.text.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
