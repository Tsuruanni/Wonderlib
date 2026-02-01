import 'package:flutter/material.dart';

import '../../providers/reader_provider.dart';

/// Wrapper widget for inline activities
/// Provides consistent styling and XP animation
class ActivityWrapper extends StatelessWidget {
  const ActivityWrapper({
    super.key,
    required this.child,
    required this.settings,
    this.isCompleted = false,
    this.isCorrect,
  });

  final Widget child;
  final ReaderSettings settings;
  final bool isCompleted;
  final bool? isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: child,
    );
  }

  Color _getBackgroundColor() {
    if (!isCompleted) {
      return settings.theme == ReaderTheme.dark
          ? const Color(0xFF2D3748)
          : const Color(0xFFF7FAFC);
    }

    if (isCorrect ?? false) {
      return settings.theme == ReaderTheme.dark
          ? const Color(0xFF1C4532)
          : const Color(0xFFC6F6D5);
    } else {
      return settings.theme == ReaderTheme.dark
          ? const Color(0xFF742A2A)
          : const Color(0xFFFED7D7);
    }
  }

  Color _getBorderColor() {
    if (!isCompleted) {
      return settings.theme == ReaderTheme.dark
          ? const Color(0xFF4A5568)
          : const Color(0xFFE2E8F0);
    }

    if (isCorrect ?? false) {
      return const Color(0xFF38A169);
    } else {
      return const Color(0xFFE53E3E);
    }
  }
}

/// XP earned animation overlay
class XPEarnedAnimation extends StatefulWidget {
  const XPEarnedAnimation({
    super.key,
    required this.xp,
    required this.onComplete,
  });

  final int xp;
  final VoidCallback onComplete;

  @override
  State<XPEarnedAnimation> createState() => _XPEarnedAnimationState();
}

class _XPEarnedAnimationState extends State<XPEarnedAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 0, end: -30).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value * (1 - (_controller.value * 0.5)),
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF38A169),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38A169).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '+${widget.xp} XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Feedback indicator for correct/incorrect answers
class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({
    super.key,
    required this.isCorrect,
  });

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCorrect ? Icons.check_circle : Icons.cancel,
          color: isCorrect ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          isCorrect ? 'Doğru!' : 'Yanlış',
          style: TextStyle(
            color: isCorrect ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
