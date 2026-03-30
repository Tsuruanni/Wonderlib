import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/word_audio_player.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Multiple choice question: EN->TR or TR->EN with 2-4 options
class VocabMultipleChoiceQuestion extends StatefulWidget {
  const VocabMultipleChoiceQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabMultipleChoiceQuestion> createState() => _VocabMultipleChoiceQuestionState();
}

class _VocabMultipleChoiceQuestionState extends State<VocabMultipleChoiceQuestion> {
  String? _selectedAnswer;
  bool _answered = false;
  final FlutterTts _tts = FlutterTts();
  final WordAudioPlayer _wordPlayer = WordAudioPlayer();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
  }

  Future<void> _speakWord(SessionQuestion q) async {
    if (q.audioUrl != null &&
        q.audioUrl!.isNotEmpty &&
        q.audioStartMs != null &&
        q.audioEndMs != null) {
      await _wordPlayer.play(
        audioUrl: q.audioUrl!,
        startMs: q.audioStartMs!,
        endMs: q.audioEndMs!,
      );
    } else {
      await _tts.speak(q.targetWord);
    }
  }

  @override
  void dispose() {
    _wordPlayer.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;
    final isReverse = q.type == QuestionType.reverseMultipleChoice;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final promptText = isReverse
        ? 'Select the correct meaning'
        : 'Select the correct English word';

    final imageSize = isWide ? 220.0 : 140.0;

    final questionCard = VocabQuestionContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!q.isRemediation)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VocabQuestionImage(imageUrl: q.imageUrl, size: imageSize),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isReverse)
                IconButton(
                  onPressed: () => _speakWord(q),
                  icon: Icon(Icons.volume_up_rounded,
                      color: theme.colorScheme.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                  ),
                ),
              if (!isReverse) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isReverse ? q.targetMeaning : q.targetWord,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final optionsList = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < (q.options?.length ?? 0); i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildOptionCard(q.options![i], q.correctAnswer),
        ],
      ],
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                promptText,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: question card (full height)
                  Expanded(child: questionCard),
                  const SizedBox(width: 24),
                  // Right: options
                  Expanded(child: optionsList),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Mobile layout — stacked
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
          questionCard,
          const SizedBox(height: 24),
          optionsList,
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option, String correctAnswer) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == correctAnswer;

    // Determine colors — 3D button style
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

    return GestureDetector(
      onTap: _answered ? null : () => _handleSelect(option),
      child: SizedBox(
        height: 54,
        child: Stack(
          children: [
            // Bottom layer (3D side)
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
            // Top layer (face)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: borderHeight,
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
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
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
