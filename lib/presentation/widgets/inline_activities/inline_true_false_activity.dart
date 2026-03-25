import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import '../common/activity_card.dart';
import '../common/animated_game_button.dart';
import '../common/feedback_animation.dart';
import 'inline_activity_sound_mixin.dart';

/// True/False inline activity widget - gamified version
class InlineTrueFalseActivity extends StatefulWidget {
  const InlineTrueFalseActivity({
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
  final void Function(bool isCorrect) onAnswer;
  final bool isCompleted;
  final bool? wasCorrect;
  final int xpValue;

  @override
  State<InlineTrueFalseActivity> createState() => _InlineTrueFalseActivityState();
}

class _InlineTrueFalseActivityState extends State<InlineTrueFalseActivity>
    with InlineActivitySoundMixin {
  bool? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  TrueFalseContent get content => widget.activity.content as TrueFalseContent;

  @override
  void initState() {
    super.initState();
    initSoundPlayer();

    if (widget.isCompleted) {
      _isAnswered = true;
      _isCorrect = widget.wasCorrect;
      _selectedAnswer = widget.wasCorrect ?? false
          ? content.correctAnswer
          : !content.correctAnswer;
    }
  }

  @override
  void dispose() {
    disposeSoundPlayer();
    super.dispose();
  }

  void _handleAnswer(bool answer) {
    if (_isAnswered || widget.isCompleted) return;

    final isCorrect = answer == content.correctAnswer;

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
      _isCorrect = isCorrect;
      if (_isCorrect!) {
        _showXPAnimation = true;
      }
    });

    playSound(isCorrect);

    if (isCorrect) {
      // Only trigger callback (which advances flow) if correct
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
           widget.onAnswer(true);
        }
      });
    } else {
       // Call onAnswer after delay to show correct answer but then unlock next flow
       Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
           widget.onAnswer(false);
        }
      });
    }
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
              // Statement
              Text(
                content.statement,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: widget.settings.fontSize,
                  fontWeight: FontWeight.w700,
                  color: widget.settings.theme == ReaderTheme.dark
                      ? Colors.black
                      : AppColors.black,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              // Options - side by side
              Row(
                children: [
                  Expanded(child: _buildOption(true, 'True')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildOption(false, 'False')),
                ],
              ),
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

  Widget _buildOption(bool value, String label) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswer == value;
    final isCorrectOption = content.correctAnswer == value;

    GameButtonVariant variant;
    if (answered) {
      if (isCorrectOption) {
        variant = GameButtonVariant.success;
      } else if (isSelected && !isCorrectOption) {
        variant = GameButtonVariant.danger;
      } else {
        variant = GameButtonVariant.neutral;
      }
    } else {
      variant = GameButtonVariant.secondary;
    }

    return AnimatedGameButton(
      label: label,
      onPressed: answered ? null : () => _handleAnswer(value),
      variant: variant,
      fullWidth: true,
    );
  }
}
