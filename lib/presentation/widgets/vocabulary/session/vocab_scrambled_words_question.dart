import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/text_styles.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/letter_tap_sound_service.dart';
import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';

/// Scrambled words: Duolingo-style word tile arrangement for phrases.
/// Shows meaning + optional image, answer line slots, and tappable word chips.
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
  int get phraseWordCount => widget.question.correctAnswer.split(' ').length;

  @override
  void dispose() {
    _tapSound.dispose();
    super.dispose();
  }

  void _tapTile(int index) {
    if (_answered || _selectedIndices.contains(index)) return;
    if (_selectedIndices.length >= phraseWordCount) return;

    setState(() => _selectedIndices.add(index));
    HapticFeedback.selectionClick();
    _tapSound.playTap(_selectedIndices.length - 1);

    if (_selectedIndices.length == phraseWordCount) {
      _submit();
    }
  }

  void _removeTile(int selectionIndex) {
    if (_answered || selectionIndex >= _selectedIndices.length) return;
    setState(() => _selectedIndices.removeAt(selectionIndex));
    HapticFeedback.lightImpact();
  }

  void _submit() {
    if (_answered) return;
    setState(() => _answered = true);
    widget.onAnswer(_selectedIndices.map((i) => tiles[i]).join(' '));
  }

  static String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    _FeedbackState feedback = _FeedbackState.none;
    if (_answered) {
      final answer = _selectedIndices.map((i) => tiles[i]).join(' ');
      feedback = _norm(answer) == _norm(widget.question.correctAnswer)
          ? _FeedbackState.correct
          : _FeedbackState.incorrect;
    }

    if (isWide) {
      return _buildWideLayout(theme, feedback);
    }
    return _buildMobileLayout(theme, feedback);
  }

  // ── MOBILE ──────────────────────────────────────────────

  Widget _buildMobileLayout(ThemeData theme, _FeedbackState feedback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // Instruction
          Text(
            'Arrange words to form the phrase',
            style: AppTextStyles.button(color: AppColors.neutralText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Prompt card
          _PromptCard(question: widget.question),
          const SizedBox(height: 20),

          // Answer zone
          Expanded(
            child: Column(
              children: [
                _AnswerZone(
                  phraseWordCount: phraseWordCount,
                  selectedIndices: _selectedIndices,
                  tiles: tiles,
                  feedback: feedback,
                  onRemove: _removeTile,
                ),
                const Spacer(),
                // Tile pool
                _TilePool(
                  tiles: tiles,
                  selectedIndices: _selectedIndices,
                  onTap: _tapTile,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── WIDE (tablet/web) ───────────────────────────────────

  Widget _buildWideLayout(ThemeData theme, _FeedbackState feedback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Arrange words to form the phrase',
              style: AppTextStyles.titleMedium(color: AppColors.neutralText).copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: prompt card
                Expanded(child: _PromptCard(question: widget.question)),
                const SizedBox(width: 32),
                // Right: answer + tiles
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AnswerZone(
                        phraseWordCount: phraseWordCount,
                        selectedIndices: _selectedIndices,
                        tiles: tiles,
                        feedback: feedback,
                        onRemove: _removeTile,
                      ),
                      const SizedBox(height: 32),
                      _TilePool(
                        tiles: tiles,
                        selectedIndices: _selectedIndices,
                        onTap: _tapTile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PROMPT CARD
// ═══════════════════════════════════════════════════════════

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.question});
  final SessionQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VocabQuestionContainer(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          VocabQuestionImage(
            imageUrl: question.imageUrl,
            size: MediaQuery.sizeOf(context).width >= 600 ? 160 : 120,
          ),
          const SizedBox(height: 12),
          // Meaning chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              question.targetMeaning,
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
}

// ═══════════════════════════════════════════════════════════
// ANSWER ZONE — underlined slots (Duolingo-style)
// ═══════════════════════════════════════════════════════════

enum _FeedbackState { none, correct, incorrect }

class _AnswerZone extends StatelessWidget {
  const _AnswerZone({
    required this.phraseWordCount,
    required this.selectedIndices,
    required this.tiles,
    required this.feedback,
    required this.onRemove,
  });

  final int phraseWordCount;
  final List<int> selectedIndices;
  final List<String> tiles;
  final _FeedbackState feedback;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 10,
      children: List.generate(phraseWordCount, (index) {
        final isFilled = index < selectedIndices.length;
        final word = isFilled ? tiles[selectedIndices[index]] : null;

        return GestureDetector(
          onTap: isFilled ? () => onRemove(index) : null,
          child: _AnswerSlot(
            word: word,
            feedback: feedback,
            theme: theme,
          ),
        );
      }),
    );
  }
}

class _AnswerSlot extends StatelessWidget {
  const _AnswerSlot({
    required this.word,
    required this.feedback,
    required this.theme,
  });

  final String? word;
  final _FeedbackState feedback;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isFilled = word != null;

    // Feedback colors
    Color lineColor;
    Color textColor;
    Color bgColor;

    switch (feedback) {
      case _FeedbackState.correct:
        lineColor = AppColors.primary;
        textColor = AppColors.primaryDark;
        bgColor = AppColors.primaryBackground.withValues(alpha: 0.5);
      case _FeedbackState.incorrect:
        lineColor = AppColors.danger;
        textColor = AppColors.dangerDark;
        bgColor = AppColors.dangerBackground.withValues(alpha: 0.5);
      case _FeedbackState.none:
        lineColor = isFilled
            ? AppColors.secondary
            : AppColors.gray300;
        textColor = theme.colorScheme.onSurface;
        bgColor = isFilled
            ? AppColors.secondaryBackground.withValues(alpha: 0.3)
            : Colors.transparent;
    }

    if (isFilled) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: lineColor, width: 2),
        ),
        child: Text(
          word!,
          style: AppTextStyles.titleMedium(color: textColor).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
        ).animate().scale(
              duration: 150.ms,
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),
      );
    }

    // Empty slot — just an underline
    return Container(
      width: 56,
      height: 38,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: lineColor, width: 2.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TILE POOL — tappable word chips
// ═══════════════════════════════════════════════════════════

class _TilePool extends StatelessWidget {
  const _TilePool({
    required this.tiles,
    required this.selectedIndices,
    required this.onTap,
  });

  final List<String> tiles;
  final List<int> selectedIndices;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 10,
      children: List.generate(tiles.length, (i) {
        final isUsed = selectedIndices.contains(i);
        return _WordChip(
          word: tiles[i],
          isUsed: isUsed,
          onTap: () => onTap(i),
        );
      }),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.isUsed,
    required this.onTap,
  });

  final String word;
  final bool isUsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Used chip → ghost placeholder (keeps layout stable)
    if (isUsed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200, width: 1.5),
        ),
        child: Text(
          word,
          style: AppTextStyles.button(color: Colors.transparent),
        ),
      );
    }

    // Available chip — 3D raised button (Duolingo signature)
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.gray200,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          word,
          style: AppTextStyles.button(color: AppColors.gray700),
        ),
      ),
    );
  }
}
