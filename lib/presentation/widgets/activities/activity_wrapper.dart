import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
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
    // Determine header color based on correctness
    Color headerColor;
    if (isCompleted) {
      if (isCorrect == true) {
        headerColor = AppColors.primary;
      } else {
        headerColor = AppColors.danger;
      }
    } else {
      headerColor = AppColors.secondary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.neutral,
          width: 2,
        ),
        boxShadow: [
          const BoxShadow(
            color: AppColors.neutral,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Activity Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted 
                      ? (isCorrect == true ? Icons.check_circle : Icons.cancel)
                      : Icons.extension_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted 
                      ? (isCorrect == true ? 'COMPLETED!' : 'NICE TRY!')
                      : 'ACTIVITY',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
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
          isCorrect ? 'Correct!' : 'Wrong!',
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
