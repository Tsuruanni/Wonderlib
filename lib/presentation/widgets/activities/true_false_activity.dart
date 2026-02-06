import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import 'common/activity_card.dart';
import 'common/animated_game_button.dart';

/// True/False inline activity widget - gamified version
class TrueFalseActivity extends StatefulWidget {
  const TrueFalseActivity({
    super.key,
    required this.activity,
    required this.settings,
    required this.onAnswer,
    this.isCompleted = false,
    this.wasCorrect,
  });

  final InlineActivity activity;
  final ReaderSettings settings;
  final void Function(bool isCorrect, int xpEarned) onAnswer;
  final bool isCompleted;
  final bool? wasCorrect;

  @override
  State<TrueFalseActivity> createState() => _TrueFalseActivityState();
}

class _TrueFalseActivityState extends State<TrueFalseActivity> {
  bool? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  late AudioPlayer _audioPlayer;

  TrueFalseContent get content => widget.activity.content as TrueFalseContent;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

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

    _playSound(isCorrect);

    if (isCorrect) {
      // Only trigger callback (which advances flow) if correct
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
           widget.onAnswer(true, widget.activity.xpReward);
        }
      });
    } else {
       // Call onAnswer after delay to show correct answer but then unlock next flow
       Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
           widget.onAnswer(false, 0);
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
                  fontSize: widget.settings.fontSize + 2,
                  fontWeight: FontWeight.w700,
                  color: widget.settings.theme == ReaderTheme.dark
                      ? Colors.black
                      : AppColors.black,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

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

  Widget _buildOption(bool value, String label) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswer == value;
    final isCorrectOption = content.correctAnswer == value;

    GameButtonVariant variant = GameButtonVariant.secondary;
    // Determine the variant based on logic only
    if (answered) {
      if (isCorrectOption) {
        variant = GameButtonVariant.success; // Always show correct answer as Green
      } else if (isSelected && !isCorrectOption) {
        variant = GameButtonVariant.danger; // Show wrong selection as Red
      } else {
        variant = GameButtonVariant.neutral; // Non-selected incorrect option
      }
    } else {
       // Default state
       if (value) {
          variant = GameButtonVariant.success; // TRUE is visually distinct? or just primary/secondary
          // Actually let's keep them uniform
          variant = GameButtonVariant.secondary;
       } else {
          variant = GameButtonVariant.secondary;
       }
    }

    return AnimatedGameButton(
      label: label,
      onPressed: answered ? null : () => _handleAnswer(value),
      variant: variant,
      fullWidth: true,
    );
  }
}
