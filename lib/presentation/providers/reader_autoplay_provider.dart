import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/content/content_block.dart';
import 'audio_sync_provider.dart';

/// Configuration for auto-play behavior
class AutoPlayConfig {
  const AutoPlayConfig({
    this.initialDelayMs = 3000,
    this.afterActivityDelayMs = 1000,
    this.afterAudioDelayMs = 500,
  });

  /// Delay before auto-playing first block on chapter load
  final int initialDelayMs;

  /// Delay after activity completion before playing next audio
  final int afterActivityDelayMs;

  /// Delay after audio completion before playing next audio
  final int afterAudioDelayMs;
}

/// State for reader auto-play
class ReaderAutoPlayState {
  const ReaderAutoPlayState({
    this.blocks = const [],
    this.hasAutoPlayedInitial = false,
    this.isAutoPlayEnabled = true,
  });

  final List<ContentBlock> blocks;
  final bool hasAutoPlayedInitial;
  final bool isAutoPlayEnabled;

  ReaderAutoPlayState copyWith({
    List<ContentBlock>? blocks,
    bool? hasAutoPlayedInitial,
    bool? isAutoPlayEnabled,
  }) {
    return ReaderAutoPlayState(
      blocks: blocks ?? this.blocks,
      hasAutoPlayedInitial: hasAutoPlayedInitial ?? this.hasAutoPlayedInitial,
      isAutoPlayEnabled: isAutoPlayEnabled ?? this.isAutoPlayEnabled,
    );
  }
}

/// Controller for reader auto-play orchestration.
/// Handles auto-play on chapter load, after activity, and after audio completion.
class ReaderAutoPlayController extends StateNotifier<ReaderAutoPlayState> {
  ReaderAutoPlayController(
    this._ref, {
    this.config = const AutoPlayConfig(),
  }) : super(const ReaderAutoPlayState());

  final Ref _ref;
  final AutoPlayConfig config;
  Timer? _initialAutoPlayTimer;

  /// Initialize with content blocks and start auto-play timer
  void initialize(List<ContentBlock> blocks) {
    state = state.copyWith(blocks: blocks);

    // Start auto-play timer if not already played
    if (!state.hasAutoPlayedInitial && state.isAutoPlayEnabled) {
      _initialAutoPlayTimer?.cancel();
      _initialAutoPlayTimer = Timer(
        Duration(milliseconds: config.initialDelayMs),
        _autoPlayFirstBlock,
      );
    }
  }

  /// Update blocks (when visibility changes)
  void updateBlocks(List<ContentBlock> blocks) {
    state = state.copyWith(blocks: blocks);
  }

  /// Find and play the first audio block
  void _autoPlayFirstBlock() {
    if (state.hasAutoPlayedInitial || !state.isAutoPlayEnabled) return;
    state = state.copyWith(hasAutoPlayedInitial: true);

    final firstAudioBlock = state.blocks.firstWhere(
      (b) => b.hasAudio,
      orElse: () => ContentBlock.empty(),
    );

    if (firstAudioBlock.id.isNotEmpty) {
      _playBlock(firstAudioBlock);
    }
  }

  /// Handle audio completion - play next audio block
  void onAudioCompleted(String completedBlockId) {
    if (!state.isAutoPlayEnabled) return;

    final currentIndex = state.blocks.indexWhere((b) => b.id == completedBlockId);
    if (currentIndex == -1) return;

    // Find next audio block
    final nextAudioBlock = _findNextAudioBlock(currentIndex);
    if (nextAudioBlock != null) {
      Future.delayed(
        Duration(milliseconds: config.afterAudioDelayMs),
        () {
          if (mounted && state.isAutoPlayEnabled) {
            _playBlock(nextAudioBlock);
          }
        },
      );
    }
  }

  /// Handle activity completion - play next audio block
  void onActivityCompleted(String activityId, List<ContentBlock> visibleBlocks) {
    if (!state.isAutoPlayEnabled) return;

    // Find the activity block
    final activityBlockIndex = state.blocks.indexWhere(
      (b) => b.isActivityBlock && b.activityId == activityId,
    );
    if (activityBlockIndex == -1) return;

    // Update visible blocks
    state = state.copyWith(blocks: visibleBlocks);

    // Find next audio block after the activity
    final nextAudioBlock = _findNextAudioBlock(activityBlockIndex);
    if (nextAudioBlock != null) {
      Future.delayed(
        Duration(milliseconds: config.afterActivityDelayMs),
        () {
          if (mounted && state.isAutoPlayEnabled) {
            _playBlock(nextAudioBlock);
          }
        },
      );
    }
  }

  /// Find the next audio block after given index
  ContentBlock? _findNextAudioBlock(int afterIndex) {
    for (int i = afterIndex + 1; i < state.blocks.length; i++) {
      if (state.blocks[i].hasAudio) {
        return state.blocks[i];
      }
    }
    return null;
  }

  /// Play a content block's audio
  void _playBlock(ContentBlock block) {
    if (!block.hasAudio) return;

    try {
      final controller = _ref.read(audioSyncControllerProvider.notifier);
      controller.loadBlock(block).then((_) => controller.play());
    } catch (e) {
      // Audio controller not ready, ignore
    }
  }

  /// Enable or disable auto-play
  void setAutoPlayEnabled(bool enabled) {
    state = state.copyWith(isAutoPlayEnabled: enabled);
    if (!enabled) {
      _initialAutoPlayTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _initialAutoPlayTimer?.cancel();
    super.dispose();
  }
}

/// Provider for reader auto-play controller
final readerAutoPlayControllerProvider =
    StateNotifierProvider.autoDispose<ReaderAutoPlayController, ReaderAutoPlayState>((ref) {
  return ReaderAutoPlayController(ref);
});

/// Provider for getting the next audio block after a given block ID
final nextAudioBlockProvider = Provider.family<ContentBlock?, String>((ref, afterBlockId) {
  final state = ref.watch(readerAutoPlayControllerProvider);
  final currentIndex = state.blocks.indexWhere((b) => b.id == afterBlockId);
  if (currentIndex == -1) return null;

  for (int i = currentIndex + 1; i < state.blocks.length; i++) {
    if (state.blocks[i].hasAudio) {
      return state.blocks[i];
    }
  }
  return null;
});
