import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'vocab_question_container.dart';
import '../../../../core/services/word_audio_player.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Listening question: audio plays, user selects or types the answer
class VocabListeningQuestion extends StatefulWidget {
  const VocabListeningQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabListeningQuestion> createState() => _VocabListeningQuestionState();
}

class _VocabListeningQuestionState extends State<VocabListeningQuestion> {
  final FlutterTts _tts = FlutterTts();
  final WordAudioPlayer _wordPlayer = WordAudioPlayer();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _answered = false;
  String? _selectedAnswer;
  bool _hasPlayedOnce = false;

  bool get isWriteMode => widget.question.type == QuestionType.listeningWrite;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Initialize TTS then auto-play
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _tts.setLanguage('en-US');
      if (!mounted) return;
      _playAudio();
      if (isWriteMode) _focusNode.requestFocus();
    });
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    // Do NOT call _tts.stop() here — AnimatedSwitcher keeps this widget alive
    // during fade-out. stop() would kill the next question's TTS mid-word
    // because all FlutterTts instances share the same platform TTS engine.
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _wordPlayer.dispose();
    super.dispose();
  }

  bool get _hasSegmentAudio =>
      widget.question.audioUrl != null &&
      widget.question.audioUrl!.isNotEmpty &&
      widget.question.audioStartMs != null &&
      widget.question.audioEndMs != null;

  Future<void> _playAudio() async {
    if (!mounted) return;
    setState(() => _hasPlayedOnce = true);

    if (_hasSegmentAudio) {
      await _wordPlayer.play(
        audioUrl: widget.question.audioUrl!,
        startMs: widget.question.audioStartMs!,
        endMs: widget.question.audioEndMs!,
      );
    } else {
      await _tts.speak(widget.question.targetWord);
    }
  }

  void _handleSelect(String option) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = option;
      _answered = true;
    });
    HapticFeedback.lightImpact();
    widget.onAnswer(option);
  }

  void _submitWritten() {
    if (_answered || _controller.text.trim().isEmpty) return;
    setState(() => _answered = true);
    HapticFeedback.lightImpact();
    widget.onAnswer(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              isWriteMode ? 'Listen and type the word' : 'Listen and select the correct word',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _playAudio,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.surfaceContainerHighest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  )
                  .animate(
                    key: ValueKey('audio_pulse_$_hasPlayedOnce'),
                    onPlay: (controller) {
                      if (!_hasPlayedOnce) {
                        controller.repeat(reverse: true);
                      }
                    },
                  )
                  .scaleXY(end: 1.1, duration: 1000.ms, curve: Curves.easeInOut),
                ),

                const SizedBox(height: 16),

                Text(
                  'Tap to listen again',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Select mode: show options
          if (!isWriteMode && widget.question.options != null)
             ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.question.options!.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = widget.question.options![index];
                return _buildOptionCard(option, theme, widget.question.correctAnswer);
              },
            ),

          // Write mode: text field
          if (isWriteMode) ...[
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_answered,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Type what you hear...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              ),
              onSubmitted: (_) => _submitWritten(),
            ),
            const SizedBox(height: 16),
            if (!_answered)
              FilledButton(
                onPressed: _controller.text.trim().isNotEmpty
                    ? _submitWritten
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Check Answer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option, ThemeData theme, String correctAnswer) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == correctAnswer;

    // Determine colors
    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.2);
    Color backgroundColor = theme.colorScheme.surface;
    Color textColor = theme.colorScheme.onSurface;
    double borderWidth = 1.0;

    if (_answered) {
      if (isCorrect) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade800;
        borderWidth = 2.0;
      } else if (isSelected && !isCorrect) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade800;
        borderWidth = 2.0;
      }
    } else if (isSelected) {
       borderColor = theme.colorScheme.primary;
       backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.05);
       borderWidth = 2.0;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _answered ? null : () => _handleSelect(option),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Text(
              option,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
