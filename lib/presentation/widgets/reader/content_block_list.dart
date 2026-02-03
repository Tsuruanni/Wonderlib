import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/activity_provider.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/content_block_provider.dart';
import '../../providers/reader_provider.dart';
import 'activity_block_widget.dart';
import 'image_block_widget.dart';
import 'text_block_widget.dart';

/// Displays a list of content blocks for a chapter.
/// Handles progressive reveal - activities must be completed to unlock next content.
/// Auto-play is handled by AudioSyncController internally.
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
  final void Function(String word, Offset position, int timingIndex, String blockId)? onWordTap;
  final ScrollController? scrollController;

  @override
  ConsumerState<ContentBlockList> createState() => _ContentBlockListState();
}

class _ContentBlockListState extends ConsumerState<ContentBlockList> {
  Set<String> _previousCompletedIds = {};
  final Map<String, GlobalKey> _blockKeys = {};
  final GlobalKey _endMarkerKey = GlobalKey();
  List<ContentBlock> _currentVisibleBlocks = [];
  bool _hasInitializedCompletedIds = false;

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

  /// Scroll to end of content (for ChapterCompletionCard)
  void _scrollToEndMarker() {
    final context = _endMarkerKey.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  /// Scroll to the next block after a completed activity
  void _scrollToNextBlockAfterActivity(String activityId, List<ContentBlock> visibleBlocks) {
    // Find the activity block
    final activityIndex = visibleBlocks.indexWhere(
      (b) => b.isActivityBlock && b.activityId == activityId,
    );

    if (activityIndex == -1) return;

    if (activityIndex >= visibleBlocks.length - 1) {
      // Last block was an activity, scroll to end marker (ChapterCompletionCard area)
      _scrollToEndMarker();
      return;
    }

    // Scroll to next block
    final nextBlock = visibleBlocks[activityIndex + 1];
    _scrollToBlock(nextBlock.id);
  }

  /// Scroll to next block after audio completes
  void _scrollToNextBlockAfterAudio(String completedBlockId, List<ContentBlock> visibleBlocks) {
    final currentIndex = visibleBlocks.indexWhere((b) => b.id == completedBlockId);
    if (currentIndex == -1) return;

    if (currentIndex < visibleBlocks.length - 1) {
      final nextBlock = visibleBlocks[currentIndex + 1];
      _scrollToBlock(nextBlock.id);
    } else {
      // Last audio block, scroll to end
      _scrollToEndMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(contentBlocksProvider(widget.chapter.id));
    final inlineActivitiesAsync = ref.watch(inlineActivitiesProvider(widget.chapter.id));
    final completedActivities = ref.watch(inlineActivityStateProvider);

    // Listen for audio completion to scroll (auto-play is handled internally by AudioSyncController)
    ref.listen<String?>(audioCompletedBlockProvider, (previous, completedBlockId) {
      if (completedBlockId != null && previous != completedBlockId) {
        // Scroll to next block after audio completes
        _scrollToNextBlockAfterAudio(completedBlockId, _currentVisibleBlocks);
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

    // Listen for chapter initialization to capture baseline completed activities
    // This prevents auto-play for activities loaded from DB (vs completed this session)
    ref.listen<bool>(chapterInitializedProvider, (previous, initialized) {
      if (initialized && !_hasInitializedCompletedIds) {
        // Chapter just finished loading - capture current completed activities as baseline
        _previousCompletedIds = ref.read(inlineActivityStateProvider).keys.toSet();
        _hasInitializedCompletedIds = true;
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

        // Store visible blocks for use in listeners
        _currentVisibleBlocks = visibleBlocks;

        // Set blocks for auto-play navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            ref.read(audioSyncControllerProvider.notifier).setBlocks(visibleBlocks);
          } catch (_) {
            // Audio controller not ready yet
          }

          // Handle case where chapterInitializedProvider is already true
          // Read CURRENT value (not captured) to handle proper timing
          final currentlyInitialized = ref.read(chapterInitializedProvider);
          if (currentlyInitialized && !_hasInitializedCompletedIds) {
            _previousCompletedIds = ref.read(inlineActivityStateProvider).keys.toSet();
            _hasInitializedCompletedIds = true;
          }
        });

        // Check for new completions to trigger scroll and auto-play
        // But ONLY for activities completed in THIS session, not loaded from DB
        // (Initialization is handled by ref.listen on chapterInitializedProvider above)
        if (_hasInitializedCompletedIds) {
          final currentCompletedIds = completedActivities.keys.toSet();
          final newlyCompletedIds = currentCompletedIds.difference(_previousCompletedIds);

          if (newlyCompletedIds.isNotEmpty) {
            _previousCompletedIds = currentCompletedIds;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Scroll to next block after the completed activity
              for (final activityId in newlyCompletedIds) {
                _scrollToNextBlockAfterActivity(activityId, visibleBlocks);
                try {
                  ref.read(audioSyncControllerProvider.notifier)
                      .onActivityCompleted(activityId, visibleBlocks);
                } catch (_) {
                  // Audio controller not ready
                }
              }
            });
          }
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
              children: [
                ...visibleBlocks.map((block) {
                  return KeyedSubtree(
                    key: _blockKeys[block.id],
                    child: _buildBlockWidget(block, activityMap),
                  );
                }),
                // End marker for scrolling to ChapterCompletionCard
                SizedBox(key: _endMarkerKey, height: 1),
              ],
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
