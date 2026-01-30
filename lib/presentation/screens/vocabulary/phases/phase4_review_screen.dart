import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/entities/vocabulary.dart';
import '../../../providers/vocabulary_provider.dart';

/// Phase 4: Review
/// Quiz with multiple choice and fill-in-blank questions
class Phase4ReviewScreen extends ConsumerStatefulWidget {
  final String listId;

  const Phase4ReviewScreen({super.key, required this.listId});

  @override
  ConsumerState<Phase4ReviewScreen> createState() => _Phase4ReviewScreenState();
}

class _Phase4ReviewScreenState extends ConsumerState<Phase4ReviewScreen> {
  int _currentIndex = 0;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _answered = false;
  int? _selectedOptionIndex;
  String _fillInAnswer = '';
  late List<_QuizQuestion> _questions;
  final Random _random = Random();
  final TextEditingController _fillInController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  @override
  void dispose() {
    _fillInController.dispose();
    super.dispose();
  }

  void _generateQuestions() {
    final words = ref.read(wordsForListProvider(widget.listId));
    if (words.isEmpty) return;

    _questions = [];

    for (final word in words) {
      // Alternate between multiple choice and fill-in-blank
      final isFillIn = _random.nextBool();

      if (isFillIn) {
        // Fill-in-blank: given definition, type the word
        _questions.add(_QuizQuestion(
          type: _QuestionType.fillInBlank,
          word: word,
          questionText: 'What word means:\n"${(word.meaningEN ?? word.meaningTR)}"',
          correctAnswer: word.word,
        ));
      } else {
        // Multiple choice: given word, pick the definition
        final wrongOptions = words
            .where((w) => w.id != word.id)
            .toList()
          ..shuffle(_random);

        final options = [
          (word.meaningEN ?? word.meaningTR),
          ...wrongOptions.take(3).map((w) => w.meaningEN ?? w.meaningTR),
        ]..shuffle(_random);

        _questions.add(_QuizQuestion(
          type: _QuestionType.multipleChoice,
          word: word,
          questionText: 'What is the meaning of "${word.word}"?',
          correctAnswer: (word.meaningEN ?? word.meaningTR),
          options: options,
        ));
      }
    }

    // Shuffle questions
    _questions.shuffle(_random);
  }

  void _checkAnswer() {
    final currentQuestion = _questions[_currentIndex];
    bool isCorrect = false;

    if (currentQuestion.type == _QuestionType.multipleChoice) {
      if (_selectedOptionIndex != null) {
        isCorrect = currentQuestion.options![_selectedOptionIndex!] ==
            currentQuestion.correctAnswer;
      }
    } else {
      isCorrect = _fillInAnswer.toLowerCase().trim() ==
          currentQuestion.correctAnswer.toLowerCase().trim();
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _answered = true;
      if (isCorrect) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOptionIndex = null;
        _fillInAnswer = '';
        _fillInController.clear();
      });
    } else {
      _completePhase();
    }
  }

  void _completePhase() {
    final total = _correctCount + _incorrectCount;
    final percentage = total > 0 ? (_correctCount / total * 100).round() : 0;
    final isPassed = percentage >= 70;

    // Mark phase as complete only if passed
    if (isPassed) {
      ref.read(wordListProgressControllerProvider.notifier)
          .completePhase(widget.listId, 4, score: _correctCount, total: total);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isPassed ? Icons.emoji_events : Icons.school,
          color: isPassed ? Colors.amber : Colors.blue,
          size: 64,
        ),
        title: Text(isPassed ? 'Congratulations!' : 'Good Effort!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                border: Border.all(
                  color: isPassed ? Colors.green : Colors.orange,
                  width: 4,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$percentage%',
                    style: context.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text(
                    '$_correctCount/$total',
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPassed
                  ? 'You\'ve completed all phases! This word list is now mastered.'
                  : 'Keep practicing to improve your score. You need 70% to pass.',
              textAlign: TextAlign.center,
            ),
            if (isPassed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '+40 XP Earned!',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isPassed)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Reset and try again
                setState(() {
                  _currentIndex = 0;
                  _correctCount = 0;
                  _incorrectCount = 0;
                  _answered = false;
                  _selectedOptionIndex = null;
                  _fillInAnswer = '';
                  _fillInController.clear();
                });
                _generateQuestions();
              },
              child: const Text('Try Again'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(isPassed ? 'Complete!' : 'Back to List'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordList = ref.watch(wordListByIdProvider(widget.listId));
    final words = ref.watch(wordsForListProvider(widget.listId));

    if (words.isEmpty || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No words in this list')),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(wordList?.name ?? 'Review'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: context.textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),

          // Score display
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScoreChip(
                  icon: Icons.check_circle,
                  count: _correctCount,
                  color: Colors.green,
                ),
                const SizedBox(width: 24),
                _ScoreChip(
                  icon: Icons.cancel,
                  count: _incorrectCount,
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question type badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: currentQuestion.type == _QuestionType.multipleChoice
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentQuestion.type == _QuestionType.multipleChoice
                                ? Icons.list
                                : Icons.edit,
                            size: 16,
                            color: currentQuestion.type ==
                                    _QuestionType.multipleChoice
                                ? Colors.blue
                                : Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentQuestion.type == _QuestionType.multipleChoice
                                ? 'Multiple Choice'
                                : 'Fill in the Blank',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: currentQuestion.type ==
                                      _QuestionType.multipleChoice
                                  ? Colors.blue
                                  : Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Question text
                  Text(
                    currentQuestion.questionText,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Answer area
                  if (currentQuestion.type == _QuestionType.multipleChoice)
                    _MultipleChoiceOptions(
                      options: currentQuestion.options!,
                      selectedIndex: _selectedOptionIndex,
                      correctAnswer: currentQuestion.correctAnswer,
                      showResult: _answered,
                      onSelect: _answered
                          ? null
                          : (index) {
                              setState(() {
                                _selectedOptionIndex = index;
                              });
                            },
                    )
                  else
                    _FillInBlankInput(
                      controller: _fillInController,
                      correctAnswer: currentQuestion.correctAnswer,
                      showResult: _answered,
                      onChanged: (value) {
                        setState(() {
                          _fillInAnswer = value;
                        });
                      },
                    ),

                  const SizedBox(height: 32),

                  // Action button
                  if (!_answered)
                    FilledButton(
                      onPressed: (currentQuestion.type ==
                                      _QuestionType.multipleChoice &&
                                  _selectedOptionIndex != null) ||
                              (currentQuestion.type == _QuestionType.fillInBlank &&
                                  _fillInAnswer.isNotEmpty)
                          ? _checkAnswer
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Check Answer'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _nextQuestion,
                      icon: Icon(_currentIndex < _questions.length - 1
                          ? Icons.arrow_forward
                          : Icons.done_all),
                      label: Text(_currentIndex < _questions.length - 1
                          ? 'Next Question'
                          : 'See Results'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _QuestionType { multipleChoice, fillInBlank }

class _QuizQuestion {
  final _QuestionType type;
  final VocabularyWord word;
  final String questionText;
  final String correctAnswer;
  final List<String>? options;

  const _QuizQuestion({
    required this.type,
    required this.word,
    required this.questionText,
    required this.correctAnswer,
    this.options,
  });
}

class _ScoreChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _ScoreChip({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: context.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultipleChoiceOptions extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final String correctAnswer;
  final bool showResult;
  final void Function(int)? onSelect;

  const _MultipleChoiceOptions({
    required this.options,
    this.selectedIndex,
    required this.correctAnswer,
    required this.showResult,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selectedIndex == index;
        final isCorrect = option == correctAnswer;

        Color? backgroundColor;
        Color? borderColor;
        IconData? trailingIcon;

        if (showResult) {
          if (isCorrect) {
            backgroundColor = Colors.green.withValues(alpha: 0.1);
            borderColor = Colors.green;
            trailingIcon = Icons.check_circle;
          } else if (isSelected && !isCorrect) {
            backgroundColor = Colors.red.withValues(alpha: 0.1);
            borderColor = Colors.red;
            trailingIcon = Icons.cancel;
          }
        } else if (isSelected) {
          backgroundColor = context.colorScheme.primaryContainer;
          borderColor = context.colorScheme.primary;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: backgroundColor ?? context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onSelect != null ? () => onSelect!(index) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor ??
                        context.colorScheme.outline.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    // Option letter
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected || (showResult && isCorrect)
                            ? (showResult
                                ? (isCorrect ? Colors.green : Colors.red)
                                : context.colorScheme.primary)
                            : context.colorScheme.surfaceContainerHighest,
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index), // A, B, C, D
                          style: context.textTheme.labelLarge?.copyWith(
                            color: isSelected || (showResult && isCorrect)
                                ? Colors.white
                                : context.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Option text
                    Expanded(
                      child: Text(
                        option,
                        style: context.textTheme.bodyLarge,
                      ),
                    ),

                    // Result icon
                    if (showResult && trailingIcon != null)
                      Icon(
                        trailingIcon,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FillInBlankInput extends StatelessWidget {
  final TextEditingController controller;
  final String correctAnswer;
  final bool showResult;
  final ValueChanged<String> onChanged;

  const _FillInBlankInput({
    required this.controller,
    required this.correctAnswer,
    required this.showResult,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect =
        controller.text.toLowerCase().trim() == correctAnswer.toLowerCase().trim();

    return Column(
      children: [
        TextField(
          controller: controller,
          enabled: !showResult,
          textAlign: TextAlign.center,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: showResult ? (isCorrect ? Colors.green : Colors.red) : null,
          ),
          decoration: InputDecoration(
            hintText: 'Type your answer...',
            filled: true,
            fillColor: showResult
                ? (isCorrect
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1))
                : context.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: showResult
                    ? (isCorrect ? Colors.green : Colors.red)
                    : context.colorScheme.outline,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colorScheme.outline.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colorScheme.primary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isCorrect ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            suffixIcon: showResult
                ? Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                  )
                : null,
          ),
          onChanged: onChanged,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
        ),

        // Show correct answer if wrong
        if (showResult && !isCorrect) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lightbulb, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'Correct answer: ',
                  style: context.textTheme.bodyLarge,
                ),
                Text(
                  correctAnswer,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
