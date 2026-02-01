import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
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

  TrueFalseContent get content => widget.activity.content as TrueFalseContent;

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
          : !content.correctAnswer;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleAnswer(bool answer) {
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

    widget.onAnswer(_isCorrect!, _isCorrect! ? widget.activity.xpReward : 0);
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
                  // Statement
                  Text(
                    content.statement,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.settings.fontSize,
                      fontWeight: FontWeight.w500,
                      color: widget.settings.theme.text,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Options - side by side
                  Row(
                    children: [
                      Expanded(child: _buildOption(true, 'Doğru')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildOption(false, 'Yanlış')),
                    ],
                  ),
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

  Widget _buildOption(bool value, String label) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswer == value;
    final isCorrectOption = content.correctAnswer == value;

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
      onTap: () => _handleAnswer(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected || (answered && isCorrectOption) ? 2 : 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
