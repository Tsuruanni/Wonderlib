import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import '../common/activity_card.dart';
import '../common/animated_game_button.dart';
import '../common/feedback_animation.dart';
import 'inline_activity_sound_mixin.dart';

/// Word translation activity widget - gamified version
class InlineWordTranslationActivity extends StatefulWidget {
  const InlineWordTranslationActivity({
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
  State<InlineWordTranslationActivity> createState() => _InlineWordTranslationActivityState();
}

class _InlineWordTranslationActivityState extends State<InlineWordTranslationActivity>
    with InlineActivitySoundMixin {
  String? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  WordTranslationContent get content =>
      widget.activity.content as WordTranslationContent;

  @override
  void initState() {
    super.initState();
    initSoundPlayer();

    if (widget.isCompleted) {
      _isAnswered = true;
      _isCorrect = widget.wasCorrect;
      _selectedAnswer = widget.wasCorrect ?? false
          ? content.correctAnswer
          : content.options.isNotEmpty
              ? content.options.firstWhere(
                  (o) => o != content.correctAnswer,
                  orElse: () => content.options.first,
                )
              : '';
    }
  }

  @override
  void didUpdateWidget(covariant InlineWordTranslationActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswer = null;
        _showXPAnimation = false;
      });
    }
  }

  @override
  void dispose() {
    disposeSoundPlayer();
    super.dispose();
  }

  void _handleAnswer(String answer) {
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
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onAnswer(
            true,
            widget.activity.vocabularyWords,
          );
        }
      });
    } else {
      // Wrong answer - still call onAnswer to mark activity complete and allow progression
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          widget.onAnswer(false, widget.activity.vocabularyWords);
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
              // Word highlight - 3D Style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gray200, // Neutral 200
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFD1D5DB), // Neutral 300
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  content.word,
                  style: GoogleFonts.nunito(
                    fontSize: widget.settings.fontSize + 2,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF374151), // Neutral 700
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Options
              ...content.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: index < content.options.length - 1 ? 8 : 0,),
                  child: _buildOption(option),
                );
              }),
            ],
          ),
        ),

        // Feedback Overlay
        if (answered && correct != null)
          Positioned.fill(
            child: FeedbackAnimation(
              isCorrect: correct,
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

  Widget _buildOption(String option) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswer == option;
    final isCorrectOption = content.correctAnswer == option;

    GameButtonVariant variant = GameButtonVariant.secondary;

    if (answered) {
      if (isCorrectOption) {
        variant = GameButtonVariant.success; // Always Green if answered
      } else if (isSelected && !isCorrectOption) {
        variant = GameButtonVariant.danger; // Red if selected and wrong
      } else {
        variant = GameButtonVariant.neutral; // Greyed out otherwise
      }
    } else {
      if (isSelected) {
         variant = GameButtonVariant.primary;
      } else {
         variant = GameButtonVariant.secondary;
      }
    }

    return AnimatedGameButton(
      label: option,
      onPressed: answered ? null : () => _handleAnswer(option),
      variant: variant,
      fullWidth: true,
    );
  }
}
