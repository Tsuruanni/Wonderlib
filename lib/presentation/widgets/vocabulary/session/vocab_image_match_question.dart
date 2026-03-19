import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';

/// Image match question: EN word shown, pick the correct image from 2 options.
/// Used in Phase 1 (Explore) for visual recognition.
class VocabImageMatchQuestion extends StatefulWidget {
  const VocabImageMatchQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabImageMatchQuestion> createState() =>
      _VocabImageMatchQuestionState();
}

class _VocabImageMatchQuestionState extends State<VocabImageMatchQuestion> {
  String? _selectedAnswer;
  bool _answered = false;

  void _handleSelect(String imageUrl) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = imageUrl;
      _answered = true;
    });
    HapticFeedback.lightImpact();
    widget.onAnswer(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = widget.question.options ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Which picture is this word?',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // Target word prominently displayed
          VocabQuestionContainer(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Text(
              widget.question.targetWord,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // 2 image options side by side
          Row(
            children: options.map((imageUrl) {
              final isSelected = _selectedAnswer == imageUrl;
              final isCorrect = imageUrl == widget.question.correctAnswer;

              Color borderColor =
                  theme.colorScheme.outline.withValues(alpha: 0.2);
              double borderWidth = 2.0;

              if (_answered) {
                if (isCorrect) {
                  borderColor = Colors.green;
                  borderWidth = 3.0;
                } else if (isSelected && !isCorrect) {
                  borderColor = Colors.red;
                  borderWidth = 3.0;
                }
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: _answered ? null : () => _handleSelect(imageUrl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: borderColor, width: borderWidth),
                        boxShadow: [
                          BoxShadow(
                            color:
                                theme.colorScheme.shadow.withValues(alpha: 0.08),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_rounded,
                                size: 48,
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate(
                        target: _answered && isCorrect ? 1.0 : 0.0,
                      )
                      .scaleXY(
                        begin: 1.0,
                        end: 1.05,
                        duration: 300.ms,
                        curve: Curves.easeOutBack,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
