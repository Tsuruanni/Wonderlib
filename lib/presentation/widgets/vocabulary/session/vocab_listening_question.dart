import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'vocab_question_container.dart';
import '../../../../app/text_styles.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/word_audio_player.dart';
import '../../../../domain/entities/vocabulary_session.dart';
import '../../../utils/app_icons.dart';
import '../../../widgets/common/game_button.dart';

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
  String? _pressedOption;
  bool _hasPlayedOnce = false;

  bool get isWriteMode => widget.question.type == QuestionType.listeningWrite;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
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

  Widget _buildAudioCard(ThemeData theme) {
    return VocabQuestionContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              child: AppIcons.soundOn(size: 48),
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
    );
  }

  Widget _buildSelectOptions() {
    final options = widget.question.options ?? [];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildOptionCard(options[i], widget.question.correctAnswer),
        ],
      ],
    );
  }

  Widget _buildWriteInput(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
            hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
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
          onSubmitted: (_) => _submitWritten(),
        ),
        const SizedBox(height: 16),
        if (!_answered)
          Center(
            child: SizedBox(
              width: 200,
              child: GameButton(
                label: 'Check Answer',
                onPressed: _controller.text.trim().isNotEmpty
                    ? _submitWritten
                    : null,
                variant: GameButtonVariant.primary,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final promptText = isWriteMode
        ? 'Listen and type the word'
        : 'Listen and select the correct word';

    final rightSide = isWriteMode
        ? _buildWriteInput(theme)
        : _buildSelectOptions();

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                promptText,
                style: AppTextStyles.titleMedium(color: AppColors.neutralText).copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildAudioCard(theme)),
                  const SizedBox(width: 24),
                  Expanded(child: rightSide),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Mobile layout
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              promptText,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          _buildAudioCard(theme),
          const SizedBox(height: 24),
          rightSide,
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option, String correctAnswer) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == correctAnswer;

    Color faceColor;
    Color sideColor;
    Color textColor;

    if (_answered && isCorrect) {
      faceColor = AppColors.primary;
      sideColor = AppColors.primaryDark;
      textColor = AppColors.white;
    } else if (_answered && isSelected && !isCorrect) {
      faceColor = AppColors.danger;
      sideColor = AppColors.dangerDark;
      textColor = AppColors.white;
    } else {
      faceColor = AppColors.white;
      sideColor = AppColors.neutral;
      textColor = AppColors.black;
    }

    const double borderHeight = 4.0;
    final isPressed = !_answered && _pressedOption == option;
    final double faceTop = isPressed ? borderHeight : 0.0;
    final double faceBottom = isPressed ? 0.0 : borderHeight;

    return GestureDetector(
      onTap: _answered ? null : () => _handleSelect(option),
      onTapDown: _answered ? null : (_) => setState(() => _pressedOption = option),
      onTapUp: _answered ? null : (_) => setState(() => _pressedOption = null),
      onTapCancel: _answered ? null : () => setState(() => _pressedOption = null),
      child: SizedBox(
        height: 54,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: borderHeight,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: faceTop,
              bottom: faceBottom,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: faceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: !_answered
                      ? Border.all(color: AppColors.neutral, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  option,
                  style: AppTextStyles.bodyMedium(color: textColor).copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
