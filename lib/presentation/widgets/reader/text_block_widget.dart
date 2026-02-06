import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/reader_provider.dart';
import 'word_highlight_text.dart';

/// Widget for rendering a text content block with audio sync support.
/// Shows inline play icon at the start of text, highlights words during playback.
class TextBlockWidget extends ConsumerWidget {
  const TextBlockWidget({
    super.key,
    required this.block,
    required this.settings,
    this.vocabulary = const [],
    this.onVocabularyTap,
    this.onWordTap,
    this.showDropCap = false,
  });

  final ContentBlock block;
  final ReaderSettings settings;
  final List<ChapterVocabulary> vocabulary;
  final void Function(ChapterVocabulary vocab, Offset position)? onVocabularyTap;
  /// Callback when a word is tapped. Used for word-tap popup (TTS pronunciation).
  final void Function(String word, Offset position)? onWordTap;
  /// Unused - kept for API compatibility
  final bool showDropCap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = block.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    // Watch audio state for this specific block
    final audioState = ref.watch(audioSyncControllerProvider);
    final activeWordIndex = ref.watch(activeWordIndexProvider(block.id));
    final isPlaying = ref.watch(isBlockPlayingProvider(block.id));
    final isLoading = ref.watch(isBlockLoadingProvider(block.id));
    final isFollowingScroll = audioState.isFollowingScroll;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: WordHighlightText(
        text: text,
        wordTimings: block.wordTimings,
        settings: settings,
        activeWordIndex: activeWordIndex,
        vocabulary: vocabulary,
        onVocabularyTap: onVocabularyTap,
        onWordTap: onWordTap,
        isFollowingScroll: isFollowingScroll,
        // Inline audio icon (scales with font)
        prefixWidgets: [
          if (block.hasAudio)
            _InlinePlayIcon(
              isPlaying: isPlaying,
              isLoading: isLoading,
              onPressed: () => _handlePlayPress(ref),
              settings: settings,
            ),
        ],
      ),
    );
  }

  void _handlePlayPress(WidgetRef ref) {
    final controller = ref.read(audioSyncControllerProvider.notifier);
    final currentState = ref.read(audioSyncControllerProvider);

    if (currentState.currentBlockId == block.id) {
      // Toggle play/pause for current block
      controller.togglePlayPause();
    } else {
      // Load and play new block
      controller.loadBlock(block).then((_) => controller.play());
    }
  }
}

/// Inline play icon that scales with font size - looks like part of the text
class _InlinePlayIcon extends StatelessWidget {
  const _InlinePlayIcon({
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
    required this.settings,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF6366F1);
    // Scale with font size - icon is roughly same height as text
    final iconSize = settings.fontSize * 1.1;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: isLoading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.headphones_rounded,
                size: iconSize,
                color: accentColor,
              ),
      ),
    );
  }
}
