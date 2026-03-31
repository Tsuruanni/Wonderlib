import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/router.dart';
import '../../../domain/entities/system_settings.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/entities/vocabulary_session.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/vocabulary_session_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/vocabulary_mascot_overlay.dart';
import '../../widgets/vocabulary/session/vocab_image_match_question.dart';
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

class VocabularySessionScreen extends ConsumerStatefulWidget {
  const VocabularySessionScreen({
    super.key,
    required this.listId,
  });

  final String listId;

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
  double _maxProgress = 0.0; // monotonic: never decreases
  // Halfway mascot state
  bool _hasShownHalfway = false;
  bool _halfwayPending = false;
  bool _halfwayVisible = false;

  // Combo milestone mascot state
  String? _comboMilestoneAsset;
  String? _comboMilestoneText;
  double _comboMilestoneSize = 130;
  int _lastComboMilestoneShown = 0;
  bool _comboMilestonePending = false;
  bool _comboMascotVisible = false;

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

    if (words.length < 2) {
      if (mounted) {
        if (words.isEmpty) {
          showAppSnackBar(context, 'This word list has no words');
          context.pop();
        } else {
          showAppSnackBar(context, 'Need at least 2 words for a session');
          context.pop();
        }
      }
      return;
    }

    // Precache all word images so they're instant when questions appear
    _precacheWordImages(words);

    ref.read(vocabularySessionControllerProvider.notifier).startSession(words);
    setState(() => _initialized = true);
  }

  void _precacheWordImages(List<VocabularyWord> words) {
    for (final word in words) {
      if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
        precacheImage(NetworkImage(word.imageUrl!), context);
      }
    }
  }

  /// Progress = answered / (answered + estimatedRemaining).
  ///
  /// Each phase estimates how many questions remain in this phase plus
  /// future phases.  [_maxProgress] ensures the bar never moves backward
  /// when estimates are revised at phase transitions.
  double _calculateProgress(VocabularySessionState s) {
    if (s.totalQuestionsAnswered == 0) return 0.0;

    final minReinforce = s.words.length + 2;
    // Live estimate: weakWords updates as the user gets answers wrong
    final targetFinal = s.weakWords.isEmpty ? 0 : min(5, s.weakWords.length);

    int estimatedRemaining;
    switch (s.phase) {
      case SessionPhase.explore:
        final pairsLeft = s.totalPairs - s.introductionPairIndex;
        estimatedRemaining = pairsLeft + minReinforce + targetFinal;
      case SessionPhase.reinforce:
        int reinforceLeft;
        if (s.reinforceQuestionsAsked < minReinforce) {
          reinforceLeft = minReinforce - s.reinforceQuestionsAsked;
        } else {
          // Past minimum — check if all words are bridged (transition condition)
          final allBridged = s.words.every(
            (w) => w.masteryLevel.index >= WordMasteryLevel.bridged.index,
          );
          if (allBridged) {
            reinforceLeft = 0;
          } else {
            final unbridged = s.words.where(
              (w) => w.masteryLevel.index < WordMasteryLevel.bridged.index,
            ).length;
            reinforceLeft = max(1, unbridged * 2);
          }
        }
        estimatedRemaining = reinforceLeft + targetFinal;
      case SessionPhase.finalPhase:
        estimatedRemaining = max(0, targetFinal - s.finalQuestionsAsked);
    }

    final raw = s.totalQuestionsAnswered /
        (s.totalQuestionsAnswered + estimatedRemaining);
    _maxProgress = max(_maxProgress, raw.clamp(0.0, 1.0));
    return _maxProgress;
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

    // Phase-aware progress: each phase estimates remaining questions
    final progress = _calculateProgress(sessionState);

    // Halfway encouragement — visible for one question after progress crosses 50%
    if (progress >= 0.5 && !_hasShownHalfway) {
      _hasShownHalfway = true;
      _halfwayPending = true;
    }
    if (_halfwayPending && !sessionState.isShowingFeedback) {
      _halfwayPending = false;
      _halfwayVisible = true;
    }
    if (_halfwayVisible && sessionState.isShowingFeedback) {
      _halfwayVisible = false; // hide when student answers
    }

    // Combo milestone mascots — trigger on 5, 10, 15 combo
    final combo = sessionState.combo;
    if (combo >= 5 && _lastComboMilestoneShown < 5) {
      _lastComboMilestoneShown = 5;
      _comboMilestonePending = true;
      _comboMilestoneAsset = 'assets/animations/mascot/lovely-owl-mascot.riv';
      _comboMilestoneText = '5x Combo!\nNice streak!';
      _comboMilestoneSize = 130;
    }
    if (combo >= 10 && _lastComboMilestoneShown < 10) {
      _lastComboMilestoneShown = 10;
      _comboMilestonePending = true;
      _comboMilestoneAsset = 'assets/animations/mascot/lovely-owl-mascot.riv';
      _comboMilestoneText = '10x Combo!\nUnstoppable!';
      _comboMilestoneSize = 130;
    }
    if (combo >= 15 && _lastComboMilestoneShown < 15) {
      _lastComboMilestoneShown = 15;
      _comboMilestonePending = true;
      _comboMilestoneAsset = 'assets/animations/mascot/lovely-owl-mascot.riv';
      _comboMilestoneText = '15x Combo!\nYou are legendary!';
      _comboMilestoneSize = 130;
    }
    // Show combo mascot when pending clears (feedback dismissed)
    if (_comboMilestonePending && !sessionState.isShowingFeedback) {
      _comboMilestonePending = false;
      _comboMascotVisible = true;
      _halfwayVisible = false; // combo takes priority over halfway
    }
    // Hide when student answers the next question
    if (_comboMascotVisible && sessionState.isShowingFeedback) {
      _comboMascotVisible = false;
    }

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
                              Image.asset('assets/icons/gem_outline_256.png', width: 18, height: 18, filterQuality: FilterQuality.high),
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
                  
                  const SizedBox(height: 8),

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

          // Halfway encouragement mascot
          if (_halfwayVisible)
            Positioned(
              bottom: 8,
              right: 8,
              child: IgnorePointer(
                child: _EncouragementMascot(
                  key: const ValueKey('halfway_mascot'),
                  asset: 'assets/animations/mascot/balloon-owl-mascot.riv',
                  text: 'Halfway there!\nKeep going!',
                ),
              ),
            ),

          // Combo milestone mascot
          if (_comboMascotVisible && _comboMilestoneAsset != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: IgnorePointer(
                child: _EncouragementMascot(
                  key: ValueKey('combo_mascot_$_lastComboMilestoneShown'),
                  asset: _comboMilestoneAsset!,
                  text: _comboMilestoneText!,
                  size: _comboMilestoneSize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleAnswer(VocabularySessionController controller, String answer) {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
    controller.answerQuestion(answer, settings: settings);
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Column(
      key: ValueKey('intro_${sessionState.introductionPairIndex}'),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
          child: Text(
            '${sessionState.introductionPairIndex + 1}/${sessionState.totalPairs}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
        // Cards: side by side on web, stacked on mobile
        if (isWide)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < pair.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: VocabWordIntroductionCard(word: pair[i])),
                  ],
                ],
              ),
            ),
          )
        else
          ...pair.map((word) => Expanded(child: VocabWordIntroductionCard(word: word))),
        const SizedBox(height: 12),
        // Continue button — centered island style
        Center(
          child: SizedBox(
            width: 200,
            child: GameButton(
              label: 'Continue',
              onPressed: controller.finishIntroduction,
              variant: GameButtonVariant.primary,
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

      case QuestionType.imageMatch:
        return VocabImageMatchQuestion(
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
            final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
            controller.answerMatchingQuestion(
              correctMatches: correctMatches,
              totalMatches: totalMatches,
              correctWordIds: correctWordIds,
              incorrectWordIds: incorrectWordIds,
              settings: settings,
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

/// Encouragement mascot with speech bubble — used for halfway and combo milestones.
/// Appears at bottom-right for one question only, doesn't block interaction.
class _EncouragementMascot extends StatelessWidget {
  const _EncouragementMascot({
    super.key,
    required this.asset,
    required this.text,
    this.size = 130,
  });

  final String asset;
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = theme.colorScheme.primaryContainer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speech bubble with tail pointing to mascot
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Bubble tail — starts from bottom-left, points down-right toward mascot
            Positioned(
              bottom: -8,
              left: 20,
              child: CustomPaint(
                size: const Size(16, 10),
                painter: _BubbleTailPainter(color: bubbleColor),
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        // Mascot animation
        SizedBox(
          width: size,
          height: size,
          child: MascotOverlay(
            asset: asset,
            size: size,
            freeze: false,
            exitSlide: false,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }
}

/// Paints a small triangle tail for the speech bubble
class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
