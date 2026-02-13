import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../widgets/common/animated_game_button.dart';
import '../../widgets/common/subtle_background.dart';
import '../../widgets/book_quiz/book_quiz_progress_bar.dart';
import '../../widgets/book_quiz/book_quiz_question_renderer.dart';
import '../../widgets/book_quiz/book_quiz_result_card.dart';

/// Full-screen quiz experience for a book's final quiz.
///
/// Guards: all chapters must be complete before taking quiz.
/// Uses PageView for one-question-per-page navigation.
class BookQuizScreen extends ConsumerStatefulWidget {
  const BookQuizScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BookQuizScreen> createState() => _BookQuizScreenState();
}

class _BookQuizScreenState extends ConsumerState<BookQuizScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isSubmitting = false;
  bool _showResults = false;

  /// Stores user answers keyed by question ID.
  /// Value type varies by question type (`String`, `List<int>`, `Map<int,int>`).
  final Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep controller alive during async submit to prevent autoDispose
    ref.watch(bookQuizControllerProvider);

    // Guard: check reading progress
    final progressAsync = ref.watch(readingProgressProvider(widget.bookId));

    return Scaffold(
      body: SubtleBackground(
        iconColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
        child: progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading progress: $e')),
          data: (progress) {
            // Guard: all chapters must be read
            if (progress == null || progress.completionPercentage < 100) {
              return _buildGuardScreen(context);
            }
            // Load quiz
            return _buildQuizContent(context);
          },
        ),
      ),
    );
  }

  Widget _buildGuardScreen(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Finish reading first!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to read all chapters before taking the quiz.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 24),
              AnimatedGameButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: 'Go Back',
                variant: GameButtonVariant.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizContent(BuildContext context) {
    final quizAsync = ref.watch(bookQuizProvider(widget.bookId));

    return quizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading quiz: $e')),
      data: (quiz) {
        if (quiz == null || quiz.questions.isEmpty) {
          return _buildNoQuizScreen(context);
        }
        return _buildQuizScaffold(context, quiz);
      },
    );
  }

  Widget _buildNoQuizScreen(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No quiz available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This book does not have a quiz yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 24),
              AnimatedGameButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: 'Go Back',
                variant: GameButtonVariant.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizScaffold(BuildContext context, BookQuiz quiz) {
    final questions = quiz.questions;
    final isLastPage = _currentPage == questions.length - 1;
    final allAnswered = _answers.length == questions.length &&
        _answers.values.every(_isAnswerValid);

    if (_showResults) {
      return _buildResultsView(context, quiz);
    }

    return SafeArea(
      child: Column(
        children: [
          // Header: Close button & Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4B5563),
                  ),
                  onPressed: () => _handleClose(context),
                ),
                Expanded(
                  child: BookQuizProgressBar(
                    currentIndex: _currentPage,
                    totalQuestions: questions.length,
                    answeredIndices: _answers.keys
                        .map((id) => questions.indexWhere((q) => q.id == id))
                        .where((i) => i >= 0)
                        .toSet(),
                  ),
                ),
              ],
            ),
          ),

          // Main Content: Question Card
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Instructions removed per user request
                          // if (index == 0 && quiz.instructions != null) ...
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: BookQuizQuestionRenderer(
                                key: ValueKey(question.id),
                                question: question,
                                onAnswer: (answer) {
                                  setState(() {
                                    _answers[question.id] = answer;
                                  });
                                },
                                currentAnswer: _answers[question.id],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0);
              },
            ),
          ),

          // Bottom Bar: Navigation
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                if (_currentPage > 0) ...[
                  Expanded(
                    child: AnimatedGameButton(
                      onPressed: _goToPreviousPage,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: 'Back',
                      variant: GameButtonVariant.neutral,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: isLastPage
                      ? AnimatedGameButton(
                          onPressed: allAnswered && !_isSubmitting
                              ? () => _submitQuiz(quiz)
                              : null,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded),
                          label:
                              _isSubmitting ? 'Submitting...' : 'Submit Quiz',
                          variant: allAnswered
                              ? GameButtonVariant.success
                              : GameButtonVariant.neutral,
                        )
                      : AnimatedGameButton(
                          onPressed: _goToNextPage,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: 'Next',
                          variant: GameButtonVariant.primary,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context, BookQuiz quiz) {
    final submissionState = ref.watch(bookQuizControllerProvider);

    return SafeArea(
      child: submissionState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to submit: $e'),
              const SizedBox(height: 16),
              AnimatedGameButton(
                onPressed: () => _submitQuiz(quiz),
                label: 'Retry',
                variant: GameButtonVariant.primary,
              ),
            ],
          ),
        ),
        data: (result) {
          if (result == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            child: BookQuizResultCard(
              result: result,
              passingScore: quiz.passingScore,
              onRetake: () => _retakeQuiz(quiz),
              onFinish: () => _finishQuiz(context),
            ),
          );
        },
      ),
    );
  }

  // ─── Navigation ───────────────────────────────

  void _goToNextPage() {
    if (_currentPage < (_pageController.page?.round() ?? 0) + 1 ||
        _currentPage < 999) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ─── Quiz Submission ──────────────────────────

  Future<void> _submitQuiz(BookQuiz quiz) async {
    if (_isSubmitting) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isSubmitting = true;
    });

    // Grade locally
    double totalScore = 0;
    double maxScore = 0;
    final answersJson = <String, dynamic>{};

    for (final question in quiz.questions) {
      final answer = _answers[question.id];
      maxScore += question.points;

      final isCorrect = _gradeQuestion(question, answer);
      if (isCorrect) {
        totalScore += question.points;
      }

      answersJson[question.id] = {
        'answer': _serializeAnswer(answer),
        'correct': isCorrect,
      };
    }

    // Submit via controller
    await ref.read(bookQuizControllerProvider.notifier).submitQuiz(
              quizId: quiz.id,
              bookId: widget.bookId,
              score: totalScore,
              maxScore: maxScore,
              answers: answersJson,
              passingScore: quiz.passingScore,
            );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _showResults = true;
      });
    }
  }

  bool _gradeQuestion(BookQuizQuestion question, dynamic answer) {
    if (answer == null) return false;

    switch (question.type) {
      case BookQuizQuestionType.multipleChoice:
        final content = question.content as MultipleChoiceContent;
        return answer == content.correctAnswer;

      case BookQuizQuestionType.fillBlank:
        final content = question.content as FillBlankContent;
        return content.checkAnswer(answer as String);

      case BookQuizQuestionType.eventSequencing:
        final content = question.content as EventSequencingContent;
        return content.checkAnswer(answer as List<int>);

      case BookQuizQuestionType.matching:
        final content = question.content as QuizMatchingContent;
        final pairs = answer as Map<int, int>;
        if (pairs.length != content.correctPairs.length) return false;
        return content.correctPairs.entries
            .every((e) => pairs[e.key] == e.value);

      case BookQuizQuestionType.whoSaysWhat:
        final content = question.content as WhoSaysWhatContent;
        final pairs = answer as Map<int, int>;
        if (pairs.length != content.correctPairs.length) return false;
        return content.correctPairs.entries
            .every((e) => pairs[e.key] == e.value);
    }
  }

  /// Converts answer to a JSON-serializable format.
  dynamic _serializeAnswer(dynamic answer) {
    if (answer is Map<int, int>) {
      return answer.map((k, v) => MapEntry(k.toString(), v));
    }
    return answer;
  }

  bool _isAnswerValid(dynamic answer) {
    if (answer == null) return false;
    if (answer is String) return answer.trim().isNotEmpty;
    if (answer is List) return answer.isNotEmpty;
    if (answer is Map) return answer.isNotEmpty;
    return true;
  }

  // ─── Actions ──────────────────────────────────

  void _retakeQuiz(BookQuiz quiz) {
    ref.read(bookQuizControllerProvider.notifier).reset();
    setState(() {
      _answers.clear();
      _currentPage = 0;
      _showResults = false;
      _isSubmitting = false;
    });
    // This might fail if controller was disposed, but usually fine
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (_pageController.hasClients) _pageController.jumpToPage(0);
    });
  }

  void _finishQuiz(BuildContext context) {
    context.pop();
  }

  void _handleClose(BuildContext context) {
    if (_answers.isEmpty) {
      context.pop();
      return;
    }

    // Confirm exit if user has answered some questions
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave quiz?'),
        content: const Text(
          'Your progress will be lost if you leave now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
