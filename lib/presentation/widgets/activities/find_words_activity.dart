import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';

/// Find words activity widget (multi-select) - compact version
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

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  FindWordsContent get content => widget.activity.content as FindWordsContent;
  int get requiredSelections => content.correctAnswers.length;

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
      if (widget.wasCorrect == true) {
        _selectedAnswers.addAll(content.correctAnswers);
      } else {
        _selectedAnswers.add(content.options.firstWhere(
          (o) => !content.correctAnswers.contains(o),
          orElse: () => content.options.first,
        ));
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                  // Instruction
                  Text(
                    content.instruction,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.settings.fontSize,
                      fontWeight: FontWeight.w500,
                      color: widget.settings.theme.text,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Chips
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: content.options.map((option) {
                      return _buildChip(option);
                    }).toList(),
                  ),

                  // Selection hint
                  if (!answered) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedAnswers.length}/$requiredSelections',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.settings.theme.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // XP Animation
            if (_showXPAnimation)
              Positioned(
                top: -8,
                right: 12,
                child: _XPBadge(
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

  Widget _buildChip(String option) {
    final bool answered = _isAnswered || widget.isCompleted;
    final isSelected = _selectedAnswers.contains(option);
    final isCorrectOption = content.correctAnswers.contains(option);

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (answered) {
      if (isCorrectOption) {
        backgroundColor = const Color(0xFF38A169);
        borderColor = const Color(0xFF38A169);
        textColor = Colors.white;
      } else if (isSelected && !isCorrectOption) {
        backgroundColor = const Color(0xFFE53E3E);
        borderColor = const Color(0xFFE53E3E);
        textColor = Colors.white;
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
      if (isSelected) {
        backgroundColor = const Color(0xFF6366F1);
        borderColor = const Color(0xFF6366F1);
        textColor = Colors.white;
      } else {
        backgroundColor = widget.settings.theme == ReaderTheme.dark
            ? const Color(0xFF374151)
            : Colors.white;
        borderColor = widget.settings.theme == ReaderTheme.dark
            ? const Color(0xFF4B5563)
            : const Color(0xFFE2E8F0);
        textColor = widget.settings.theme.text;
      }
    }

    return GestureDetector(
      onTap: () => _toggleOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isSelected || (answered && isCorrectOption) ? 2 : 1.5,
          ),
        ),
        child: Text(
          option,
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

class _XPBadge extends StatefulWidget {
  const _XPBadge({required this.xp, required this.onComplete});
  final int xp;
  final VoidCallback onComplete;

  @override
  State<_XPBadge> createState() => _XPBadgeState();
}

class _XPBadgeState extends State<_XPBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF38A169), Color(0xFF48BB78)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 14),
              const SizedBox(width: 3),
              Text(
                '+${widget.xp}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
