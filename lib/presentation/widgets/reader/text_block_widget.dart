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
  });

  final ContentBlock block;
  final ReaderSettings settings;
  final List<ChapterVocabulary> vocabulary;
  final void Function(ChapterVocabulary vocab, Offset position)? onVocabularyTap;
  /// Callback when a word is tapped. Used for word-tap popup (TTS pronunciation).
  final void Function(String word, Offset position)? onWordTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = block.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    // Watch audio state for this specific block
    final activeWordIndex = ref.watch(activeWordIndexProvider(block.id));
    final isPlaying = ref.watch(isBlockPlayingProvider(block.id));
    final isLoading = ref.watch(isBlockLoadingProvider(block.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inline play/pause icon at start of paragraph
          if (block.hasAudio) ...[
            _InlinePlayIcon(
              isPlaying: isPlaying,
              isLoading: isLoading,
              onPressed: () => _handlePlayPress(ref),
              settings: settings,
            ),
            const SizedBox(width: 8),
          ],
          // Text content with word highlighting
          Expanded(
            child: WordHighlightText(
              text: text,
              wordTimings: block.wordTimings,
              settings: settings,
              activeWordIndex: activeWordIndex,
              vocabulary: vocabulary,
              onVocabularyTap: onVocabularyTap,
              onWordTap: onWordTap,
            ),
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

/// Compact inline play/pause icon that sits at the start of a paragraph
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 24,
        height: 24,
        margin: EdgeInsets.only(top: settings.fontSize * 0.15),
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFF4F46E5)
              : const Color(0xFF4F46E5).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPlaying ? Colors.white : const Color(0xFF4F46E5),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 16,
                color: isPlaying ? Colors.white : const Color(0xFF4F46E5),
              ),
      ),
    );
  }
}
