import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/reader_provider.dart';
import 'word_highlight_text.dart';

/// Widget for rendering a text content block with audio sync support.
/// Shows play button if block has audio, highlights words during playback.
class TextBlockWidget extends ConsumerWidget {
  const TextBlockWidget({
    super.key,
    required this.block,
    required this.settings,
    this.vocabulary = const [],
    this.onVocabularyTap,
  });

  final ContentBlock block;
  final ReaderSettings settings;
  final List<ChapterVocabulary> vocabulary;
  final void Function(ChapterVocabulary vocab, Offset position)? onVocabularyTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = block.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    // Watch audio state for this specific block
    final activeWordIndex = ref.watch(activeWordIndexProvider(block.id));
    final isPlaying = ref.watch(isBlockPlayingProvider(block.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text content with word highlighting
          WordHighlightText(
            text: text,
            wordTimings: block.wordTimings,
            settings: settings,
            activeWordIndex: activeWordIndex,
            vocabulary: vocabulary,
            onVocabularyTap: onVocabularyTap,
          ),

          // Inline play button for blocks with audio
          if (block.hasAudio) ...[
            const SizedBox(height: 8),
            _PlayButton(
              blockId: block.id,
              isPlaying: isPlaying,
              onPressed: () => _handlePlayPress(ref),
            ),
          ],
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

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.blockId,
    required this.isPlaying,
    required this.onPressed,
  });

  final String blockId;
  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 4),
            Text(
              isPlaying ? 'Pause' : 'Listen',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
