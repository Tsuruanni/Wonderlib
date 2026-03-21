import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/services/word_audio_player.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image -- hero element, fills most of the card
            Flexible(
              flex: 3,
              child: VocabQuestionImage(imageUrl: word.imageUrl, size: 200),
            ),

            const SizedBox(height: 10),

            // Word + speaker + meaning — single row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SpeakerButton(
                  word: word.word,
                  audioUrl: word.audioUrl,
                  audioStartMs: word.audioStartMs,
                  audioEndMs: word.audioEndMs,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    word.word,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    word.meaningTR,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Example sentence
            if (word.exampleSentence != null) ...[
              const SizedBox(height: 6),
              Text(
                '"${word.exampleSentence}"',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
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
  const _SpeakerButton({
    required this.word,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
  });
  final String word;
  final String? audioUrl;
  final int? audioStartMs;
  final int? audioEndMs;

  @override
  State<_SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<_SpeakerButton> {
  final FlutterTts _tts = FlutterTts();
  final WordAudioPlayer _wordPlayer = WordAudioPlayer();
  bool _isPlaying = false;

  bool get _hasSegmentAudio =>
      widget.audioUrl != null &&
      widget.audioUrl!.isNotEmpty &&
      widget.audioStartMs != null &&
      widget.audioEndMs != null;

  @override
  void initState() {
    super.initState();
    if (!_hasSegmentAudio) _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _wordPlayer.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    setState(() => _isPlaying = true);

    if (_hasSegmentAudio) {
      await _wordPlayer.play(
        audioUrl: widget.audioUrl!,
        startMs: widget.audioStartMs!,
        endMs: widget.audioEndMs!,
      );
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _tts.speak(widget.word);
    }
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
