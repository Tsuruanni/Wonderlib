import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_image.dart';

/// Faz 1 flashcard: vertical centered layout -- image hero, word + meaning below.
/// Designed to be wrapped in Expanded so it fills available space.
class VocabWordIntroductionCard extends StatelessWidget {
  const VocabWordIntroductionCard({
    super.key,
    required this.word,
  });

  final WordSessionState word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image -- hero element
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140, maxWidth: 140),
                child: VocabQuestionImage(imageUrl: word.imageUrl, size: 140),
              ),
            ),

            const SizedBox(height: 14),

            // Word + speaker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    word.word,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _SpeakerButton(word: word.word),
              ],
            ),

            const SizedBox(height: 8),

            // Turkish meaning pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                word.meaningTR,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            // Example sentence
            if (word.exampleSentence != null) ...[
              const SizedBox(height: 10),
              Text(
                '"${word.exampleSentence}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeakerButton extends StatefulWidget {
  const _SpeakerButton({required this.word});
  final String word;

  @override
  State<_SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<_SpeakerButton> {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    // Do NOT call _tts.stop() here -- AnimatedSwitcher keeps this widget alive
    // during fade-out. If the next question is a VocabListeningQuestion, its TTS
    // starts before this dispose runs, and stop() would kill it mid-word.
    super.dispose();
  }

  Future<void> _speak() async {
    setState(() => _isPlaying = true);
    await _tts.speak(widget.word);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: _isPlaying ? null : _speak,
        icon: Icon(
          _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
    );
  }
}
