import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../activities/common/feedback_animation.dart';

/// Feedback overlay after answering: green check or red X with correct answer
class QuestionFeedback extends StatefulWidget {
  const QuestionFeedback({
    super.key,
    required this.isCorrect,
    this.correctAnswer,
    this.targetWord,
    this.xpGained = 0,
    this.combo = 0,
    required this.onDismiss,
  });

  final bool isCorrect;
  final String? correctAnswer;
  final String? targetWord;
  final int xpGained;
  final int combo;
  final VoidCallback onDismiss;

  @override
  State<QuestionFeedback> createState() => _QuestionFeedbackState();
}

class _QuestionFeedbackState extends State<QuestionFeedback> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    // Auto-dismiss for correct answers after delay
    if (widget.isCorrect) {
      _autoDismissTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = widget.isCorrect;

    final colorScheme = isCorrect 
        ? const ColorScheme.light(
            surface: Color(0xFFD7FFB8),
            onSurface: Color(0xFF58A700),
            primary: Color(0xFF58A700),
            onPrimary: Colors.white,
          )
        : const ColorScheme.light(
            surface: Color(0xFFFFDFE0),
            onSurface: Color(0xFFEA2B2B),
            primary: Color(0xFFEA2B2B),
            onPrimary: Colors.white,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FeedbackAnimation(
                  isCorrect: isCorrect,
                  size: isCorrect ? 60 : 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect ? 'Excellent!' : 'Incorrect',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ).animate().fadeIn(duration: 300.ms).moveX(begin: 20, end: 0),
                      if (!isCorrect && widget.correctAnswer != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Correct answer: ',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.correctAnswer!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (isCorrect) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on, color: Color(0xFFEAB308), size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '+${widget.xpGained}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF58A700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
                            if (widget.combo >= 2) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Text(
                                  'COMBO x${widget.combo}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onDismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'GOT IT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
