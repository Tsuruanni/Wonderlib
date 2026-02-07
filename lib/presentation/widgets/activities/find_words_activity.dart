import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import 'common/activity_card.dart';
import 'common/animated_game_button.dart';

/// Find words activity widget (multi-select) - gamified version
class FindWordsActivity extends StatefulWidget {
  const FindWordsActivity({
    super.key,
    required this.activity,
    required this.settings,
    required this.onAnswer,
    this.isCompleted = false,
    this.wasCorrect,
  });

  final InlineActivity activity;
  final ReaderSettings settings;
  final void Function(bool isCorrect, int xpEarned, List<String> wordsLearned) onAnswer;
  final bool isCompleted;
  final bool? wasCorrect;

  @override
  State<FindWordsActivity> createState() => _FindWordsActivityState();
}

class _FindWordsActivityState extends State<FindWordsActivity>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedAnswers = {};
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  FindWordsContent get content => widget.activity.content as FindWordsContent;
  int get requiredSelections => content.correctAnswers.length;

  @override
  void initState() {
    super.initState();

    if (widget.isCompleted) {
      _isAnswered = true;
      _isCorrect = widget.wasCorrect;
      if (widget.wasCorrect ?? false) {
        _selectedAnswers.addAll(content.correctAnswers);
      } else {
        _selectedAnswers.add(content.options.firstWhere(
          (o) => !content.correctAnswers.contains(o),
          orElse: () => content.options.first,
        ),);
      }
    }
  }

  void _toggleOption(String option) {
    if (_isAnswered || widget.isCompleted) return;

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

    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
      if (_isCorrect!) {
        _showXPAnimation = true;
      }
    });

    widget.onAnswer(
      _isCorrect!,
      _isCorrect! ? widget.activity.xpReward : 0,
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
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 80,
                    color: correct ? const Color(0xFF2F855A).withValues(alpha: 0.8) : const Color(0xFFC53030).withValues(alpha: 0.8), // Slightly transparent icon
                    shadows: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // XP Animation
        if (_showXPAnimation)
          Positioned(
            top: 10,
            right: 0,
            child: XPBadge(
              xp: widget.activity.xpReward,
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
