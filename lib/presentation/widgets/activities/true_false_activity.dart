import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/game_button.dart';
import '../common/xp_badge.dart';

/// True/False inline activity widget - compact version
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

class _TrueFalseActivityState extends State<TrueFalseActivity>
    with SingleTickerProviderStateMixin {
  bool? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AudioPlayer _audioPlayer;

  TrueFalseContent get content => widget.activity.content as TrueFalseContent;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

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
    _animationController.dispose();
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
        _animationController.forward();
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

    Color cardColor;
    Color borderColor;

    if (answered && correct != null) {
      if (correct) {
        // Soft Green for success
        cardColor = const Color(0xFFF0FFF4); 
        borderColor = const Color(0xFF38A169);
      } else {
        // Soft Red for error
        cardColor = const Color(0xFFFFF5F5);
        borderColor = const Color(0xFFE53E3E); 
      }
      
      // Dark mode adjustments if needed
      if (widget.settings.theme == ReaderTheme.dark) {
         if (correct) {
            cardColor = const Color(0xFF064E3B);
            borderColor = const Color(0xFF34D399);
         } else {
            cardColor = const Color(0xFF450A0A);
            borderColor = const Color(0xFFF87171);
         }
      }
    } else {
      cardColor = widget.settings.theme == ReaderTheme.dark
          ? const Color(0xFF1F2937)
          : Colors.white;
      borderColor = widget.settings.theme == ReaderTheme.dark
          ? const Color(0xFF374151)
          : const Color(0xFFE2E8F0);
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
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
                          ? Colors.white
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
                  
                  // Feedback Section
                  if (answered && correct != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: correct 
                            ? (widget.settings.theme == ReaderTheme.dark ? const Color(0xFF065F46) : const Color(0xFFC6F6D5))
                            : (widget.settings.theme == ReaderTheme.dark ? const Color(0xFF7F1D1D) : const Color(0xFFFED7D7)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            correct ? Icons.check_circle : Icons.cancel,
                            color: correct 
                                ? (widget.settings.theme == ReaderTheme.dark ? const Color(0xFF34D399) : const Color(0xFF2F855A))
                                : (widget.settings.theme == ReaderTheme.dark ? const Color(0xFFF87171) : const Color(0xFFC53030)),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            correct ? 'Correct!' : 'Wrong!',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: correct 
                                  ? (widget.settings.theme == ReaderTheme.dark ? const Color(0xFFD1FAE5) : const Color(0xFF22543D))
                                  : (widget.settings.theme == ReaderTheme.dark ? const Color(0xFFFEE2E2) : const Color(0xFF742A2A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // XP Animation
            if (_showXPAnimation)
              Positioned(
                top: -10, // Adjusted to be inside checking clip behavior
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
        ),
      ),
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
        variant = GameButtonVariant.primary; // Always show correct answer as Green
      } else if (isSelected && !isCorrectOption) {
        variant = GameButtonVariant.danger; // Show wrong selection as Red
      } else {
        variant = GameButtonVariant.neutral; // Non-selected incorrect option
      }
    } else {
       // Default state
       variant = GameButtonVariant.secondary;
    }

    return GameButton(
      label: label,
      onPressed: answered ? null : () => _handleAnswer(value),
      variant: variant,
      fullWidth: true,
    );
  }
}
