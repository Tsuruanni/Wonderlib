import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/entities/book_quiz.dart';
import '../../../domain/usecases/book_quiz/grade_book_quiz_usecase.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/usecase_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../utils/app_icons.dart';
import '../../widgets/common/animated_game_button.dart';
import '../../widgets/common/game_button.dart';
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
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _stopwatch.start();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setQuizActive(bool active) {
    ref.read(quizActiveProvider.notifier).state = active;
  }

  @override
  Widget build(BuildContext context) {
    // Keep controller alive during async submit to prevent autoDispose
    ref.watch(bookQuizControllerProvider);

    // Guard: check reading progress
    final progressAsync = ref.watch(readingProgressProvider(widget.bookId));

    // Don't block navigation if results are showing or quiz hasn't started
    final isQuizActive = !_showResults && _answers.isNotEmpty;

    return PopScope(
      canPop: !isQuizActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirmation(context);
      },
      child: Scaffold(
        body: SubtleBackground(
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
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcons.warning(size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Leave Quiz?',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your progress will be lost.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: AppColors.neutralText,
                  ),
                ),
                const SizedBox(height: 24),
                GameButton(
                  label: 'Keep going',
                  onPressed: () => Navigator.of(ctx).pop(),
                  variant: GameButtonVariant.primary,
                  fullWidth: true,
                ),
                const SizedBox(height: 8),
                GameButton(
                  label: 'Leave',
                  onPressed: () {
                    _setQuizActive(false);
                    Navigator.of(ctx).pop();
                    context.go(AppRoutes.library);
                  },
                  variant: GameButtonVariant.danger,
                  fullWidth: true,
                ),
              ],
            ),
          ),
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
              AppIcons.book(size: 64),
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
                icon: AppIcons.arrowBack(),
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
                icon: AppIcons.arrowBack(),
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
    final allAnswered = quiz.questions.every((q) => _answers[q.id] != null);

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
                  icon: AppIcons.close(size: 28),
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
                                  _setQuizActive(true);
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
                      icon: AppIcons.arrowBack(),
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
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

    // Grade locally via UseCase
    final gradeUseCase = ref.read(gradeBookQuizUseCaseProvider);
    final gradeResult = gradeUseCase(GradeBookQuizParams(
      quiz: quiz,
      answers: _answers,
    ),);

    // Submit via controller
    await ref.read(bookQuizControllerProvider.notifier).submitQuiz(
              quizId: quiz.id,
              bookId: widget.bookId,
              score: gradeResult.totalScore,
              maxScore: gradeResult.maxScore,
              answers: gradeResult.answersJson,
              passingScore: quiz.passingScore,
              timeSpent: _stopwatch.elapsed.inSeconds,
            );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _showResults = true;
      });
      _setQuizActive(false);
    }
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
    _stopwatch.reset();
    _stopwatch.start();
    // This might fail if controller was disposed, but usually fine
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (_pageController.hasClients) _pageController.jumpToPage(0);
    });
  }

  void _finishQuiz(BuildContext context) {
    context.go(AppRoutes.library);
  }

  void _handleClose(BuildContext context) {
    if (_answers.isEmpty) {
      _setQuizActive(false);
      context.go(AppRoutes.library);
      return;
    }

    _showExitConfirmation(context);
  }
}
