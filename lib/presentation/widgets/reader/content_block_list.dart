import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/activity_provider.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/content_block_provider.dart';
import '../../providers/reader_autoplay_provider.dart';
import '../../providers/reader_provider.dart';
import 'activity_block_widget.dart';
import 'image_block_widget.dart';
import 'text_block_widget.dart';

/// Displays a list of content blocks for a chapter.
/// Handles progressive reveal - activities must be completed to unlock next content.
/// Delegates auto-play orchestration to ReaderAutoPlayController.
class ContentBlockList extends ConsumerStatefulWidget {
  const ContentBlockList({
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
  ConsumerState<ContentBlockList> createState() => _ContentBlockListState();
}

class _ContentBlockListState extends ConsumerState<ContentBlockList> {
  Set<String> _previousCompletedIds = {};
  final Map<String, GlobalKey> _blockKeys = {};

  void _scrollToBlock(String blockId) {
    final key = _blockKeys[blockId];
    if (key?.currentContext == null) return;

    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  void _scrollToNewContent() {
    if (widget.scrollController == null || !widget.scrollController!.hasClients) {
      return;
    }

    final currentPosition = widget.scrollController!.position.pixels;
    final maxScroll = widget.scrollController!.position.maxScrollExtent;
    final targetPosition = (currentPosition + 200).clamp(0.0, maxScroll);

    widget.scrollController!.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(contentBlocksProvider(widget.chapter.id));
    final inlineActivitiesAsync = ref.watch(inlineActivitiesProvider(widget.chapter.id));
    final completedActivities = ref.watch(inlineActivityStateProvider);
    final autoPlayController = ref.watch(readerAutoPlayControllerProvider.notifier);

    // Listen for audio completion to trigger next block
    ref.listen<String?>(audioCompletedBlockProvider, (previous, completedBlockId) {
      if (completedBlockId != null && previous != completedBlockId) {
        autoPlayController.onAudioCompleted(completedBlockId);
        ref.read(audioCompletedBlockProvider.notifier).state = null;
      }
    });

    // Listen for audio state changes to auto-scroll
    ref.listen<AudioSyncState>(audioSyncControllerProvider, (previous, current) {
      if (current.currentBlockId != null &&
          previous?.currentBlockId != current.currentBlockId &&
          current.isPlaying) {
        _scrollToBlock(current.currentBlockId!);
      }
    });

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

        // Build visible blocks (stop at first uncompleted activity)
        final visibleBlocks = _getVisibleBlocks(blocks, activityMap, completedActivities);

        // Initialize auto-play controller with blocks and chapter ID
        WidgetsBinding.instance.addPostFrameCallback((_) {
          autoPlayController.initialize(visibleBlocks, chapterId: widget.chapter.id);
        });

        // Check for new completions to trigger scroll and auto-play
        final currentCompletedIds = completedActivities.keys.toSet();
        final newlyCompletedIds = currentCompletedIds.difference(_previousCompletedIds);

        if (newlyCompletedIds.isNotEmpty) {
          _previousCompletedIds = currentCompletedIds;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToNewContent();
            // Notify controller of activity completions
            for (final activityId in newlyCompletedIds) {
              autoPlayController.onActivityCompleted(activityId, visibleBlocks);
            }
          });
        }

        // Initialize block keys
        for (final block in visibleBlocks) {
          _blockKeys.putIfAbsent(block.id, () => GlobalKey());
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: visibleBlocks.map((block) {
                return KeyedSubtree(
                  key: _blockKeys[block.id],
                  child: _buildBlockWidget(block, activityMap),
                );
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
          onWordTap: widget.onWordTap,
        );

      case ContentBlockType.image:
        return ImageBlockWidget(
          block: block,
          settings: widget.settings,
        );

      case ContentBlockType.audio:
        return TextBlockWidget(
          block: block,
          settings: widget.settings,
          vocabulary: widget.chapter.vocabulary,
          onVocabularyTap: widget.onVocabularyTap,
          onWordTap: widget.onWordTap,
        );

      case ContentBlockType.activity:
        final activity = block.activityId != null
            ? activityMap[block.activityId]
            : null;
        return ActivityBlockWidget(
          block: block,
          settings: widget.settings,
          activity: activity,
          onActivityCompleted: (isCorrect, xpEarned) {},
        );
    }
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
