import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import '../common/activity_card.dart';
import '../common/animated_game_button.dart';
import '../common/feedback_animation.dart';
import 'inline_activity_sound_mixin.dart';

/// Find words activity widget (multi-select) - gamified version
class InlineFindWordsActivity extends StatefulWidget {
  const InlineFindWordsActivity({
    super.key,
    required this.activity,
    required this.settings,
    required this.onAnswer,
    this.isCompleted = false,
    this.wasCorrect,
    this.xpValue = 25,
  });

  final InlineActivity activity;
  final ReaderSettings settings;
  final void Function(bool isCorrect, List<String> wordsLearned) onAnswer;
  final bool isCompleted;
  final bool? wasCorrect;
  final int xpValue;

  @override
  State<InlineFindWordsActivity> createState() => _InlineFindWordsActivityState();
}

class _InlineFindWordsActivityState extends State<InlineFindWordsActivity>
    with InlineActivitySoundMixin {
  final Set<String> _selectedAnswers = {};
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  FindWordsContent get content => widget.activity.content as FindWordsContent;
  int get requiredSelections => content.correctAnswers.length;

  @override
  void initState() {
    super.initState();
    initSoundPlayer();

    if (widget.isCompleted) {
      _isAnswered = true;
      _isCorrect = widget.wasCorrect;
      if (widget.wasCorrect ?? false) {
        _selectedAnswers.addAll(content.correctAnswers);
      } else {
        if (content.options.isNotEmpty) {
          _selectedAnswers.add(content.options.firstWhere(
            (o) => !content.correctAnswers.contains(o),
            orElse: () => content.options.first,
          ),);
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant InlineFindWordsActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswers.clear();
        _showXPAnimation = false;
      });
    }
  }

  @override
  void dispose() {
    disposeSoundPlayer();
    super.dispose();
  }

  void _toggleOption(String option) {
    if (_isAnswered || widget.isCompleted) return;
    if (requiredSelections == 0) return; // No correct answers defined

    setState(() {
      if (_selectedAnswers.contains(option)) {
        _selectedAnswers.remove(option);
      } else {
        if (_selectedAnswers.length < requiredSelections) {
          _selectedAnswers.add(option);
        }
      }
    });

    if (_selectedAnswers.length == requiredSelections) {
      _submitAnswer();
    }
  }

  void _submitAnswer() {
    if (_isAnswered) return;

    final correctSet = content.correctAnswers.toSet();
    final isCorrect = _selectedAnswers.length == correctSet.length &&
        _selectedAnswers.every((answer) => correctSet.contains(answer));

    playSound(isCorrect);

    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
      if (_isCorrect!) {
        _showXPAnimation = true;
      }
    });

    widget.onAnswer(
      _isCorrect!,
      widget.activity.vocabularyWords,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool answered = _isAnswered || widget.isCompleted;
    final bool? correct = _isCorrect ?? widget.wasCorrect;

    // Determine card variant
    ActivityCardVariant cardVariant = ActivityCardVariant.neutral;
    if (answered && correct != null) {
      cardVariant = correct ? ActivityCardVariant.correct : ActivityCardVariant.wrong;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivityCard(
          variant: cardVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Instruction
              Text(
                content.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.settings.fontSize,
                  fontWeight: FontWeight.bold,
                  color: widget.settings.theme == ReaderTheme.dark
                      ? Colors.black // Card background is white/light in this design
                      : Colors.black87,
                  height: 1.4,
                  fontFamily: 'Nunito',
                ),
              ),

              const SizedBox(height: 12),

              // Chips / Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 8,
                children: content.options.map((option) {
                  return _buildOptionButton(option);
                }).toList(),
              ),

              // Selection hint
              if (!answered) ...[
                const SizedBox(height: 16),
                Text(
                  'Select ${requiredSelections - _selectedAnswers.length} more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Feedback Overlay
         if (answered && correct != null)
           Positioned.fill(
            child: Center(
              child: FeedbackAnimation(
                isCorrect: correct,
              ),
            ),
          ),

        // XP Animation
        if (_showXPAnimation)
          Positioned(
            top: 10,
            right: 0,
            child: XPBadge(
              xp: widget.xpValue,
              onComplete: () {
                if (mounted) {
                  setState(() => _showXPAnimation = false);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOptionButton(String option) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswers.contains(option);
    final isCorrectOption = content.correctAnswers.contains(option);

    GameButtonVariant variant = GameButtonVariant.neutral;

    if (answered) {
      if (isCorrectOption) {
        variant = GameButtonVariant.success; // All correct answers turn Green
      } else if (isSelected && !isCorrectOption) {
        variant = GameButtonVariant.danger; // Selected wrong answers turn Red
      } else {
        variant = GameButtonVariant.neutral; // Non-selected wrong answers stay Neutral
      }
    } else {
      if (isSelected) {
        variant = GameButtonVariant.secondary;
      } else {
        variant = GameButtonVariant.neutral;
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 80),
      child: AnimatedGameButton(
        label: option,
        onPressed: answered ? null : () => _toggleOption(option),
        variant: variant,
        height: 40, // Smaller than default
        borderRadius: 12, // Compact
        textStyle: TextStyle(
          color: (variant == GameButtonVariant.neutral || variant == GameButtonVariant.outline)
             ? Colors.black87
             : Colors.white,
           fontWeight: FontWeight.bold,
           fontSize: 13,
        ),
      ),
    );
  }
}
