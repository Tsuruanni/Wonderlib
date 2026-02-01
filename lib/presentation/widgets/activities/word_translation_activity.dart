import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';

/// Word translation activity widget - compact version
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

class _WordTranslationActivityState extends State<WordTranslationActivity>
    with SingleTickerProviderStateMixin {
  String? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  WordTranslationContent get content =>
      widget.activity.content as WordTranslationContent;

  @override
  void initState() {
    super.initState();
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
      _selectedAnswer = widget.wasCorrect == true
          ? content.correctAnswer
          : content.options.firstWhere(
              (o) => o != content.correctAnswer,
              orElse: () => content.options.first,
            );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleAnswer(String answer) {
    if (_isAnswered || widget.isCompleted) return;

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
      _isCorrect = answer == content.correctAnswer;
      if (_isCorrect!) {
        _showXPAnimation = true;
        _animationController.forward();
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

    Color cardColor;
    Color borderColor;

    if (answered && correct != null) {
      if (correct) {
        cardColor = const Color(0xFF38A169).withValues(alpha: 0.1);
        borderColor = const Color(0xFF38A169).withValues(alpha: 0.5);
      } else {
        cardColor = const Color(0xFFE53E3E).withValues(alpha: 0.1);
        borderColor = const Color(0xFFE53E3E).withValues(alpha: 0.5);
      }
    } else {
      cardColor = widget.settings.theme == ReaderTheme.dark
          ? const Color(0xFF1F2937)
          : const Color(0xFFF8FAFC);
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
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Word highlight
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.15),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '«${content.word}»',
                      style: TextStyle(
                        fontSize: widget.settings.fontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Options
                  ...content.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index < content.options.length - 1 ? 8 : 0),
                      child: _buildOption(option),
                    );
                  }),
                ],
              ),
            ),

            // XP Animation
            if (_showXPAnimation)
              Positioned(
                top: -8,
                right: 12,
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

  Widget _buildOption(String option) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswer == option;
    final isCorrectOption = content.correctAnswer == option;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (answered) {
      if (isCorrectOption) {
        backgroundColor = const Color(0xFF38A169).withValues(alpha: 0.2);
        borderColor = const Color(0xFF38A169);
        textColor = const Color(0xFF38A169);
      } else if (isSelected && !isCorrectOption) {
        backgroundColor = const Color(0xFFE53E3E).withValues(alpha: 0.2);
        borderColor = const Color(0xFFE53E3E);
        textColor = const Color(0xFFE53E3E);
      } else {
        backgroundColor = widget.settings.theme == ReaderTheme.dark
            ? const Color(0xFF374151).withValues(alpha: 0.5)
            : const Color(0xFFF1F5F9);
        borderColor = Colors.transparent;
        textColor = widget.settings.theme == ReaderTheme.dark
            ? const Color(0xFF6B7280)
            : const Color(0xFF94A3B8);
      }
    } else {
      backgroundColor = widget.settings.theme == ReaderTheme.dark
          ? const Color(0xFF374151)
          : Colors.white;
      borderColor = widget.settings.theme == ReaderTheme.dark
          ? const Color(0xFF4B5563)
          : const Color(0xFFE2E8F0);
      textColor = widget.settings.theme.text;
    }

    return GestureDetector(
      onTap: () => _handleAnswer(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected || (answered && isCorrectOption) ? 2 : 1.5,
          ),
        ),
        child: Text(
          option,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: isSelected || (answered && isCorrectOption)
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
