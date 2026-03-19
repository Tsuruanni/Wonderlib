import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';

/// Pronunciation question: Image + TR meaning shown, say the English word.
/// Falls back to spelling (TextField) when mic is unavailable.
class VocabPronunciationQuestion extends StatefulWidget {
  const VocabPronunciationQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onMicDisabled,
  });

  final SessionQuestion question;
  final ValueChanged<String> onAnswer;
  final VoidCallback onMicDisabled;

  @override
  State<VocabPronunciationQuestion> createState() =>
      _VocabPronunciationQuestionState();
}

class _VocabPronunciationQuestionState
    extends State<VocabPronunciationQuestion> {
  static const _maxAttempts = 3;

  bool _isFallbackMode = false;
  bool _isListening = false;
  bool _answered = false;
  bool _sttAvailable = false;
  bool _waitingForResult = false; // true between stop and result/timeout
  int _attemptsUsed = 0;
  String? _statusMessage;

  final SpeechToText _stt = SpeechToText();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _noResultTimer;

  int get _attemptsLeft => _maxAttempts - _attemptsUsed;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _initSpeech();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _initSpeech() async {
    try {
      final available = await _stt.initialize(
        onError: (error) {
          if (mounted && !_answered) {
            _switchToFallback();
          }
        },
      );
      if (mounted) {
        if (!available) {
          _switchToFallback();
        } else {
          setState(() => _sttAvailable = true);
        }
      }
    } catch (_) {
      if (mounted) _switchToFallback();
    }
  }

  void _switchToFallback() {
    if (_isFallbackMode) return;
    setState(() => _isFallbackMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    widget.onMicDisabled();
  }

  void _toggleListening() async {
    if (_answered) return;

    if (_isListening) {
      // Stop listening — wait for final result
      await _stt.stop();
      if (mounted) {
        setState(() => _isListening = false);
        // Fallback timeout if no final result arrives
        _noResultTimer?.cancel();
        _noResultTimer = Timer(const Duration(milliseconds: 3000), () {
          if (!_answered && _waitingForResult && mounted) {
            _handleAttemptResult(null);
          }
        });
      }
    } else {
      // Start listening
      if (!_sttAvailable) return;
      setState(() {
        _isListening = true;
        _waitingForResult = true;
        _statusMessage = null;
      });
      try {
        await _stt.listen(
          localeId: 'en-US',
          onResult: _onSpeechResult,
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            cancelOnError: true,
            autoPunctuation: false,
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _waitingForResult = false;
          });
          _handleAttemptResult(null);
        }
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_answered) return;

    debugPrint('STT result: "${result.recognizedWords}" final=${result.finalResult} conf=${result.confidence}');

    if (!result.finalResult) {
      // Show partial result as status
      final partial = result.recognizedWords.trim();
      if (partial.isNotEmpty && mounted) {
        setState(() => _statusMessage = 'Hearing: "$partial"');
      }
      return;
    }

    // Final result
    _noResultTimer?.cancel();
    _waitingForResult = false;
    if (mounted) setState(() => _isListening = false);

    final recognizedWord = result.recognizedWords.trim().toLowerCase();
    _handleAttemptResult(recognizedWord.isEmpty ? null : recognizedWord);
  }

  void _handleAttemptResult(String? recognizedWord) {
    _waitingForResult = false;
    _attemptsUsed++;

    final correctAnswer = widget.question.correctAnswer.toLowerCase();

    // Correct answer on any attempt → success
    if (recognizedWord != null && recognizedWord == correctAnswer) {
      setState(() => _answered = true);
      HapticFeedback.lightImpact();
      widget.onAnswer(widget.question.correctAnswer);
      return;
    }

    // Still have attempts left → show retry message
    if (_attemptsLeft > 0) {
      setState(() {
        if (recognizedWord == null) {
          _statusMessage = "Didn't catch that. Try again ($_attemptsLeft left)";
        } else {
          _statusMessage = 'Heard "$recognizedWord" — try again ($_attemptsLeft left)';
        }
      });
      return;
    }

    // All attempts used → fall back to spelling mode
    setState(() {
      _isFallbackMode = true;
      _statusMessage = "Try typing instead";
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // Note: do NOT call onMicDisabled here — this is a per-question fallback,
    // not a session-level mic disable. Pronunciation can still appear next time.
  }

  void _submitSpelling() {
    if (_answered || _textController.text.trim().isEmpty) return;
    setState(() => _answered = true);
    HapticFeedback.lightImpact();
    widget.onAnswer(_textController.text.trim());
  }

  @override
  void dispose() {
    _stt.stop();
    _noResultTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
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
              _isFallbackMode ? 'Type the English word' : 'Say the English word',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Column(
              children: [
                VocabQuestionImage(
                  imageUrl: widget.question.imageUrl,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    widget.question.targetMeaning,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (_isFallbackMode) _buildSpellingMode(theme) else _buildMicMode(theme),
        ],
      ),
    );
  }

  Widget _buildMicMode(ThemeData theme) {
    return Column(
      children: [
        if (_statusMessage != null) ...[
          Text(
            _statusMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _statusMessage!.startsWith('Hearing')
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Tap to start/stop recording
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isListening ? 100 : 80,
            height: _isListening ? 100 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              _isListening ? Icons.stop : Icons.mic,
              size: _isListening ? 44 : 36,
              color: _isListening
                  ? Colors.white
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _isListening
              ? 'Listening... tap to stop'
              : _attemptsUsed == 0
                  ? 'Tap to speak'
                  : 'Tap to try again',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        if (_attemptsUsed > 0 && !_answered) ...[
          const SizedBox(height: 4),
          Text(
            '$_attemptsLeft attempt${_attemptsLeft == 1 ? '' : 's'} left',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const SizedBox(height: 24),

        TextButton(
          onPressed: _answered ? null : _switchToFallback,
          child: Text(
            "Can't use microphone?",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpellingMode(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          enabled: !_answered,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'Type answer...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
          onSubmitted: (_) => _submitSpelling(),
        ),

        const SizedBox(height: 20),

        if (!_answered)
          FilledButton(
            onPressed:
                _textController.text.trim().isNotEmpty ? _submitSpelling : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Check Answer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
