import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/letter_tap_sound_service.dart';
import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';

/// Scrambled words: tap word tiles in correct order to form the phrase.
/// Includes distractor tiles that don't belong to the phrase.
class VocabScrambledWordsQuestion extends StatefulWidget {
  const VocabScrambledWordsQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabScrambledWordsQuestion> createState() =>
      _VocabScrambledWordsQuestionState();
}

class _VocabScrambledWordsQuestionState
    extends State<VocabScrambledWordsQuestion> {
  final List<int> _selectedIndices = [];
  bool _answered = false;
  final _tapSound = LetterTapSoundService();

  List<String> get tiles => widget.question.scrambledWordTiles ?? [];

  /// Number of answer slots = number of words in the phrase (not including distractors).
  int get phraseWordCount => widget.question.correctAnswer.split(' ').length;

  @override
  void dispose() {
    _tapSound.dispose();
    super.dispose();
  }

  void _tapTile(int index) {
    if (_answered || _selectedIndices.contains(index)) return;
    if (_selectedIndices.length >= phraseWordCount) return;

    setState(() {
      _selectedIndices.add(index);
    });

    HapticFeedback.selectionClick();
    _tapSound.playTap(_selectedIndices.length - 1);

    // Auto-submit when all phrase slots are filled
    if (_selectedIndices.length == phraseWordCount) {
      _submit();
    }
  }

  void _removeTile(int selectionIndex) {
    if (_answered) return;
    if (selectionIndex >= _selectedIndices.length) return;

    setState(() {
      _selectedIndices.removeAt(selectionIndex);
    });
    HapticFeedback.lightImpact();
  }

  void _submit() {
    if (_answered) return;
    setState(() => _answered = true);
    final answer = _selectedIndices.map((i) => tiles[i]).join(' ');
    widget.onAnswer(answer);
  }

  /// Capitalize first letter of first and last word for display.
  String _displayWord(String word, int indexInPhrase) {
    if (word.isEmpty) return word;
    final phraseWords = widget.question.correctAnswer.split(' ');
    if (indexInPhrase == 0 || indexInPhrase == phraseWords.length - 1) {
      return word[0].toUpperCase() + word.substring(1);
    }
    return word;
  }

  Widget _buildQuestionCard(ThemeData theme, bool isWide) {
    return VocabQuestionContainer(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VocabQuestionImage(
            imageUrl: widget.question.imageUrl,
            size: isWide ? 180 : 140,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.question.targetMeaning,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordArea(ThemeData theme) {
    _SlotStatus slotStatus = _SlotStatus.neutral;
    if (_answered) {
      final answer = _selectedIndices.map((i) => tiles[i]).join(' ');
      final normalizedAnswer = _normalizeForCompare(answer);
      final normalizedCorrect =
          _normalizeForCompare(widget.question.correctAnswer);
      slotStatus = normalizedAnswer == normalizedCorrect
          ? _SlotStatus.correct
          : _SlotStatus.incorrect;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Answer Slots (only phraseWordCount slots)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 12,
          children: List.generate(phraseWordCount, (index) {
            final isFilled = index < _selectedIndices.length;
            final word = isFilled ? tiles[_selectedIndices[index]] : '';

            return GestureDetector(
              onTap: isFilled ? () => _removeTile(index) : null,
              child: _WordSlot(
                word: isFilled ? _displayWord(word, index) : '',
                isFilled: isFilled,
                status: _answered ? slotStatus : _SlotStatus.neutral,
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        // Word Tile Pool (all tiles including distractors)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: List.generate(tiles.length, (i) {
            final isUsed = _selectedIndices.contains(i);
            return _WordTile(
              word: tiles[i],
              isUsed: isUsed,
              onTap: () => _tapTile(i),
            );
          }),
        ),
      ],
    );
  }

  static String _normalizeForCompare(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Arrange words to form the phrase',
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
                  Expanded(child: _buildQuestionCard(theme, true)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildWordArea(theme)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Mobile
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Arrange words to form the phrase',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuestionCard(theme, false),
          const SizedBox(height: 32),
          _buildWordArea(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _SlotStatus { neutral, correct, incorrect }

class _WordSlot extends StatelessWidget {
  const _WordSlot({
    required this.word,
    required this.isFilled,
    required this.status,
  });

  final String word;
  final bool isFilled;
  final _SlotStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.3);
    Color bgColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    Color textColor = theme.colorScheme.onSurface;

    if (status == _SlotStatus.correct) {
      borderColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green.shade800;
    } else if (status == _SlotStatus.incorrect) {
      borderColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red.shade800;
    } else if (isFilled) {
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isFilled || status != _SlotStatus.neutral ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ]
            : [],
      ),
      child: isFilled
          ? Text(
              word,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
          : Container(
              width: 24,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.isUsed,
    required this.onTap,
  });

  final String word;
  final bool isUsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isUsed ? 0.0 : 1.0,
      child: IgnorePointer(
        ignoring: isUsed,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 56),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                word,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
