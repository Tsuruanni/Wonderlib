import 'package:flutter/material.dart';

import '../../../domain/entities/book_quiz.dart';
import 'book_quiz_event_sequencing.dart';
import 'book_quiz_fill_blank.dart';
import 'book_quiz_matching.dart';
import 'book_quiz_multiple_choice.dart';
import 'book_quiz_who_says_what.dart';

/// Factory widget that renders the correct question widget
/// based on [BookQuizQuestionType].
class BookQuizQuestionRenderer extends StatelessWidget {
  const BookQuizQuestionRenderer({
    super.key,
    required this.question,
    required this.onAnswer,
    this.currentAnswer,
  });

  final BookQuizQuestion question;

  /// Generic callback: the answer type depends on question type.
  /// - multipleChoice: `String` (selected option)
  /// - fillBlank: `String` (typed text)
  /// - eventSequencing: `List<int>` (order of indices)
  /// - matching: `Map<int, int>` (left index -> right index)
  /// - whoSaysWhat: `Map<int, int>` (character index -> quote index)
  final void Function(dynamic answer) onAnswer;

  /// The user's current answer for this question, if any.
  /// Type matches the onAnswer output.
  final dynamic currentAnswer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            question.question,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
          ),
        ),
        const SizedBox(height: 8),
        // Render question-type-specific widget
        _buildQuestionWidget(),
      ],
    );
  }

  Widget _buildQuestionWidget() {
    switch (question.type) {
      case BookQuizQuestionType.multipleChoice:
        return BookQuizMultipleChoice(
          content: question.content as MultipleChoiceContent,
          onAnswer: (selected) => onAnswer(selected),
          selectedAnswer: currentAnswer as String?,
        );

      case BookQuizQuestionType.fillBlank:
        return BookQuizFillBlank(
          content: question.content as FillBlankContent,
          onAnswer: (text) => onAnswer(text),
          currentAnswer: currentAnswer as String?,
        );

      case BookQuizQuestionType.eventSequencing:
        return BookQuizEventSequencing(
          content: question.content as EventSequencingContent,
          onAnswer: (order) => onAnswer(order),
          currentOrder: currentAnswer as List<int>?,
        );

      case BookQuizQuestionType.matching:
        return BookQuizMatching(
          content: question.content as QuizMatchingContent,
          onAnswer: (pairs) => onAnswer(pairs),
          currentPairs: currentAnswer as Map<int, int>?,
        );

      case BookQuizQuestionType.whoSaysWhat:
        return BookQuizWhoSaysWhat(
          content: question.content as WhoSaysWhatContent,
          onAnswer: (pairs) => onAnswer(pairs),
          currentPairs: currentAnswer as Map<int, int>?,
        );
    }
  }
}
