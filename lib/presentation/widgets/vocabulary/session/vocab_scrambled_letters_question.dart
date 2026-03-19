import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/letter_tap_sound_service.dart';
import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';

/// Scrambled letters: tap letters in correct order to spell the word
class VocabScrambledLettersQuestion extends StatefulWidget {
  const VocabScrambledLettersQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabScrambledLettersQuestion> createState() => _VocabScrambledLettersQuestionState();
}

class _VocabScrambledLettersQuestionState extends State<VocabScrambledLettersQuestion> {
  final List<String> _selectedLetters = [];
  final List<int> _usedIndices = [];
  bool _answered = false;
  final _tapSound = LetterTapSoundService();

  List<String> get letters => widget.question.scrambledLetters ?? [];
  String get correctWord => widget.question.correctAnswer;

  @override
  void dispose() {
    _tapSound.dispose();
    super.dispose();
  }

  void _tapLetter(int index) {
    if (_answered || _usedIndices.contains(index)) return;

    setState(() {
      _selectedLetters.add(letters[index]);
      _usedIndices.add(index);
    });

    HapticFeedback.selectionClick();
    _tapSound.playTap(_selectedLetters.length - 1);

    // Auto-submit when all letters selected
    if (_selectedLetters.length == letters.length) {
      _submit();
    }
  }

  void _removeLetter(int selectionIndex) {
    if (_answered) return;
    if (selectionIndex >= _selectedLetters.length) return;

    // Find which pool index this letter came from via reverse lookup isn't trivial
    // because we store usedIndices in order of selection.
    // _usedIndices[selectionIndex] corresponds to _selectedLetters[selectionIndex]

    setState(() {
      _selectedLetters.removeAt(selectionIndex);
      _usedIndices.removeAt(selectionIndex);
    });
    HapticFeedback.lightImpact();
  }

  void _submit() {
    if (_answered) return;
    setState(() => _answered = true);
    final answer = _selectedLetters.join();
    widget.onAnswer(answer);
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
              'Arrange letters to form the word',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                // Image + Hint
                VocabQuestionImage(imageUrl: widget.question.imageUrl),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
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

                const SizedBox(height: 24),

                // Answer Slots
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 12,
                  children: List.generate(letters.length, (index) {
                    final isFilled = index < _selectedLetters.length;
                    final char = isFilled ? _selectedLetters[index] : '';

                    return GestureDetector(
                      onTap: isFilled ? () => _removeLetter(index) : null,
                      child: _LetterSlot(
                        char: char,
                        isFilled: isFilled,
                        status: _answered
                            ? (_selectedLetters.join().toLowerCase() == correctWord.toLowerCase()
                                ? _SlotStatus.correct
                                : _SlotStatus.incorrect)
                            : _SlotStatus.neutral,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Letter Pool
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: List.generate(letters.length, (i) {
              final isUsed = _usedIndices.contains(i);
              return _LetterTile(
                char: letters[i],
                isUsed: isUsed,
                onTap: () => _tapLetter(i),
              );
            }),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _SlotStatus { neutral, correct, incorrect }

class _LetterSlot extends StatelessWidget {
  const _LetterSlot({
    required this.char,
    required this.isFilled,
    required this.status,
  });

  final String char;
  final bool isFilled;
  final _SlotStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.3);
    Color bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
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
      width: 48,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isFilled || status != _SlotStatus.neutral ? 2 : 1,
        ),
        boxShadow: isFilled ? [
          BoxShadow(
             color: theme.colorScheme.shadow.withValues(alpha: 0.05),
             offset: const Offset(0, 2),
             blurRadius: 4,
          )
        ] : [],
      ),
      child: isFilled
          ? Text(
              char.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
          : Container(
              width: 8,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.char,
    required this.isUsed,
    required this.onTap,
  });

  final String char;
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
              width: 56,
              height: 56,
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
                   )
                ],
              ),
              child: Text(
                char.toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(
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
