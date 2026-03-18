import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/router.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/entities/vocabulary_session.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/vocabulary_session_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/vocabulary_mascot_overlay.dart';
import '../../widgets/vocabulary/session/vocab_listening_question.dart';
import '../../widgets/vocabulary/session/vocab_matching_question.dart';
import '../../widgets/vocabulary/session/vocab_multiple_choice_question.dart';
import '../../widgets/vocabulary/session/vocab_question_feedback.dart';
import '../../widgets/vocabulary/session/vocab_scrambled_letters_question.dart';
import '../../widgets/vocabulary/session/vocab_word_wheel_question.dart';
import '../../widgets/vocabulary/session/vocab_sentence_gap_question.dart';
import '../../widgets/vocabulary/session/vocab_session_progress_bar.dart';
import '../../widgets/vocabulary/session/vocab_pronunciation_question.dart';
import '../../widgets/vocabulary/session/vocab_spelling_question.dart';
import '../../widgets/vocabulary/session/vocab_word_introduction_card.dart';
import '../../widgets/vocabulary/session/vocab_word_wheel_question.dart';

class VocabularySessionScreen extends ConsumerStatefulWidget {
  const VocabularySessionScreen({
    super.key,
    required this.listId,
    this.retryWordIds,
  });

  final String listId;
  final List<String>? retryWordIds; // If set, only these words (for "Tekrar Calis")

  @override
  ConsumerState<VocabularySessionScreen> createState() =>
      _VocabularySessionScreenState();
}

class _VocabularySessionScreenState
    extends ConsumerState<VocabularySessionScreen> {
  bool _initialized = false;
  final _incorrectMascotPicker = MascotPicker(incorrectMascotAssets);
  final _correctMascotPicker = MascotPicker(correctMascotAssets);
  final _audioPlayer = AudioPlayer();
  String? _currentMascotAsset;
  bool? _currentMascotCorrect;
  int _lastFeedbackQuestion = -1;

  @override
  void initState() {
    super.initState();
    _loadAndStart();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playFeedbackSound(bool isCorrect) {
    _audioPlayer
        .setAsset('assets/sounds/${isCorrect ? 'correctvoc' : 'falsevoc'}.mp3')
        .then((_) => _audioPlayer.play())
        .catchError((_) {});
  }

  Future<void> _loadAndStart() async {
    final wordsResult = await ref.read(wordsForListProvider(widget.listId).future);
    if (!mounted) return;

    List<VocabularyWord> words = wordsResult;

    // Filter to retry words if specified
    if (widget.retryWordIds != null && widget.retryWordIds!.isNotEmpty) {
      words = words
          .where((w) => widget.retryWordIds!.contains(w.id))
          .toList();
    }

    if (words.length < 2) {
      if (mounted) {
        if (words.isEmpty) {
          context.pop();
        } else {
          showAppSnackBar(context, 'Need at least 2 words for a session');
          context.pop();
        }
      }
      return;
    }

    ref.read(vocabularySessionControllerProvider.notifier).startSession(words);
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the session provider early to keep it alive during async _loadAndStart.
    // Without this, autoDispose disposes the provider before the first real build.
    final sessionState = ref.watch(vocabularySessionControllerProvider);
    final controller = ref.read(vocabularySessionControllerProvider.notifier);
    final theme = Theme.of(context);

    // Pick mascot for each new feedback (correct or incorrect)
    if (sessionState.isShowingFeedback &&
        sessionState.totalQuestionsAnswered != _lastFeedbackQuestion) {
      _lastFeedbackQuestion = sessionState.totalQuestionsAnswered;
      _currentMascotCorrect = sessionState.lastAnswerCorrect;
      _currentMascotAsset = sessionState.lastAnswerCorrect
          ? _correctMascotPicker.next()
          : _incorrectMascotPicker.next();
      _playFeedbackSound(sessionState.lastAnswerCorrect);
    }

    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Session complete → navigate to summary
    if (sessionState.isSessionComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(
            AppRoutes.vocabularySessionSummaryPath(widget.listId),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Estimate total questions for progress bar
    final estimatedTotal = sessionState.words.length * 2 + 4; // rough estimate
    final progress = sessionState.totalQuestionsAnswered / estimatedTotal;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface, // Base background
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Top Bar: Progress + Close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 28),
                          onPressed: () => _showExitDialog(context),
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: VocabSessionProgressBar(
                            progress: progress,
                            xpEarned: sessionState.xpEarned,
                            comboActive: sessionState.combo >= 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // XP Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${sessionState.xpEarned}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Main content area
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutQuad,
                      switchOutCurve: Curves.easeInQuad,
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.2, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _buildContent(sessionState, controller),
                    ),
                  ),
                  
                  // Spacer for feedback area height to prevent content being hidden behind it
                  // Only if we want content to scroll above? 
                  // For now, let's leave it full height, but maybe add bottom padding equal to expected feedback height?
                  // Actually, just letting it be is fine for now as feedback is an overlay.
                ],
              ),
            ),
          ),
          
          // Feedback Footer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFooter(sessionState, controller, theme),
          ),

          // Mascot overlay for incorrect answers (left side)
          if (sessionState.isShowingFeedback &&
              _currentMascotAsset != null &&
              _currentMascotCorrect == false)
            Positioned(
              bottom: 110,
              right: 30,
              child: IgnorePointer(
                child: MascotOverlay(
                  key: ValueKey('mascot_$_lastFeedbackQuestion'),
                  asset: _currentMascotAsset!,
                  size: 185.0,
                  freeze: false,
                ),
              ),
            ),

          // Mascot overlay for correct answers (right side, lower)
          if (sessionState.isShowingFeedback &&
              _currentMascotAsset != null &&
              _currentMascotCorrect == true)
            Positioned(
              bottom: 30,
              right: 30,
              child: IgnorePointer(
                child: MascotOverlay(
                  key: ValueKey('mascot_$_lastFeedbackQuestion'),
                  asset: _currentMascotAsset!,
                  size: 257.0,
                  slideRight: true,
                  playDuration: const Duration(milliseconds: 800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleAnswer(VocabularySessionController controller, String answer) {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    controller.answerQuestion(answer);
  }

  Widget _buildFooter(
    VocabularySessionState sessionState,
    VocabularySessionController controller,
    ThemeData theme,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutQuint,
      switchOutCurve: Curves.easeInQuart,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      child: sessionState.isShowingFeedback
          ? VocabQuestionFeedback(
              key: const ValueKey('feedback'),
              isCorrect: sessionState.lastAnswerCorrect,
              correctAnswer: sessionState.lastCorrectAnswer,
              targetWord: sessionState.currentQuestion?.type == QuestionType.matching
                  ? null
                  : sessionState.currentQuestion?.targetWord,
              questionType: sessionState.currentQuestion?.type,
              xpGained: sessionState.lastXPGained,
              combo: sessionState.combo,
              comboWarning: !sessionState.lastAnswerCorrect && sessionState.comboWarningActive,
              comboBroken: sessionState.lastComboBroken,
              onDismiss: controller.dismissFeedback,
            )
          : const SizedBox.shrink(),
    ); 
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit session?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to quit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Quit',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    VocabularySessionState sessionState,
    VocabularySessionController controller,
  ) {
    // Faz 1: Introduction cards or easy question
    if (sessionState.phase == SessionPhase.explore) {
      if (sessionState.isShowingIntroduction) {
        return _buildIntroductionCards(sessionState, controller);
      }
    }

    // Question display
    final question = sessionState.currentQuestion;
    if (question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildQuestion(question, controller, sessionState.questionIndex);
  }

  Widget _buildIntroductionCards(
    VocabularySessionState sessionState,
    VocabularySessionController controller,
  ) {
    final pair = sessionState.currentPair;
    if (pair.isEmpty) return const SizedBox.shrink();

    return Column(
      key: ValueKey('intro_${sessionState.introductionPairIndex}'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Learn these words (${sessionState.introductionPairIndex + 1}/${sessionState.totalPairs})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        ...pair.map((word) => Expanded(child: VocabWordIntroductionCard(word: word))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.finishIntroduction,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuestion(
    SessionQuestion question,
    VocabularySessionController controller,
    int questionIndex,
  ) {
    // Use questionIndex (monotonically increasing) to guarantee unique keys.
    // SessionQuestion extends Equatable, so hashCode is content-based — two
    // consecutive questions for the same word with the same option order would
    // produce the same key, causing AnimatedSwitcher to reuse the old widget
    // element (with _answered = true), making the UI non-interactive.
    final key = ValueKey('q_$questionIndex');

    switch (question.type) {
      case QuestionType.multipleChoice:
      case QuestionType.reverseMultipleChoice:
        return VocabMultipleChoiceQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );

      case QuestionType.listeningSelect:
      case QuestionType.listeningWrite:
        return VocabListeningQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );

      case QuestionType.matching:
        return VocabMatchingQuestion(
          key: key,
          question: question,
          onComplete: ({
            required correctMatches,
            required totalMatches,
            required correctWordIds,
            required incorrectWordIds,
          }) {
            // Matching doesn't use keyboard, but good to unfocus anyway
            FocusScope.of(context).unfocus();
            controller.answerMatchingQuestion(
              correctMatches: correctMatches,
              totalMatches: totalMatches,
              correctWordIds: correctWordIds,
              incorrectWordIds: incorrectWordIds,
            );
          },
        );

      case QuestionType.scrambledLetters:
        return VocabScrambledLettersQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );

      case QuestionType.wordWheel:
        return VocabWordWheelQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );

      case QuestionType.spelling:
        return VocabSpellingQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );

      case QuestionType.pronunciation:
        return VocabPronunciationQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
          onMicDisabled: () => controller.disableMicForSession(),
        );

      case QuestionType.sentenceGap:
        return VocabSentenceGapQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );
    }
  }
}

