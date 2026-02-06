import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import 'common/activity_card.dart';
import 'common/animated_game_button.dart';

/// Word translation activity widget - gamified version
class WordTranslationActivity extends StatefulWidget {
  const WordTranslationActivity({
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
  State<WordTranslationActivity> createState() => _WordTranslationActivityState();
}

class _WordTranslationActivityState extends State<WordTranslationActivity> {
  String? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  late AudioPlayer _audioPlayer;

  WordTranslationContent get content =>
      widget.activity.content as WordTranslationContent;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    if (widget.isCompleted) {
      _isAnswered = true;
      _isCorrect = widget.wasCorrect;
      _selectedAnswer = widget.wasCorrect ?? false
          ? content.correctAnswer
          : content.options.firstWhere(
              (o) => o != content.correctAnswer,
              orElse: () => content.options.first,
            );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(bool isCorrect) async {
    try {
      if (isCorrect) {
        await _audioPlayer.setAsset('assets/audio/correct.mp3');
      } else {
        await _audioPlayer.setAsset('assets/audio/wrong.mp3');
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
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

    _playSound(isCorrect);

    if (isCorrect) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onAnswer(
            true,
            widget.activity.xpReward,
            widget.activity.vocabularyWords,
          );
        }
      });
    } else {
      // Wrong answer - still call onAnswer to mark activity complete and allow progression
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          widget.onAnswer(false, 0, widget.activity.vocabularyWords);
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB), // Neutral 200
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
                    fontSize: widget.settings.fontSize + 4,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF374151), // Neutral 700
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Options
              ...content.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: index < content.options.length - 1 ? 12 : 0,),
                  child: _buildOption(option),
                );
              }),
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
                    decoration: BoxDecoration(
                      color: correct ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1), // More transparent
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
