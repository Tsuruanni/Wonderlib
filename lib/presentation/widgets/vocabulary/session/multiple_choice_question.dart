import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'question_container.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Multiple choice question: EN→TR or TR→EN with 2-4 options
class MultipleChoiceQuestion extends StatefulWidget {
  const MultipleChoiceQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<MultipleChoiceQuestion> createState() => _MultipleChoiceQuestionState();
}

class _MultipleChoiceQuestionState extends State<MultipleChoiceQuestion> {
  String? _selectedAnswer;
  bool _answered = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _handleSelect(String option) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = option;
      _answered = true;
    });
    HapticFeedback.lightImpact();
    widget.onAnswer(option);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;
    final isReverse = q.type == QuestionType.reverseMultipleChoice;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt Text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              isReverse ? 'Select the correct meaning' : 'Select the correct English word',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 12),

          QuestionContainer(
            child: Column(
              children: [
                // Icon / Media
                if (q.imageUrl != null && !q.isRemediation) 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        q.imageUrl!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),

                // Target Word
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isReverse)
                      IconButton(
                        onPressed: () => _tts.speak(q.targetWord),
                        icon: Icon(Icons.volume_up_rounded, color: theme.colorScheme.primary),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        ),
                      ),
                    if (!isReverse) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isReverse ? q.targetMeaning : q.targetWord,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Options Grid
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: q.options?.length ?? 0,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final option = q.options![index]; // safe: index < length
              return _buildOptionCard(option, theme, q.correctAnswer);
            },
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option, ThemeData theme, String correctAnswer) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == correctAnswer;
    
    // Determine colors
    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.2);
    Color backgroundColor = theme.colorScheme.surface;
    Color textColor = theme.colorScheme.onSurface;
    double borderWidth = 1.0;
    double elevation = 2.0;

    if (_answered) {
      if (isCorrect) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade800;
        borderWidth = 2.0;
      } else if (isSelected && !isCorrect) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade800;
        borderWidth = 2.0;
      }
    } else if (isSelected) {
       // This state might not be visible if we submit immediately, 
       // but useful if we change to "Check" button later.
       borderColor = theme.colorScheme.primary;
       backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.05);
       borderWidth = 2.0;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _answered ? null : () => _handleSelect(option),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Text(
              option,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
