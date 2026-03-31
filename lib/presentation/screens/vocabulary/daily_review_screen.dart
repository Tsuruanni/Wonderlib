import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/sm2_algorithm.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../providers/daily_quest_provider.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/pro_progress_bar.dart';

/// Daily Review Screen - Anki-style spaced repetition flashcards
class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key, this.unitId});

  /// If set, reviews all words in this unit (cram mode).
  final String? unitId;

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen>
    with TickerProviderStateMixin {
  bool _isFlipped = false;
  bool _isDismissing = false;
  double _dismissDirection = -1.0; // -1 = left (hard), +1 = right (good/easy)
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _dismissController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Load session on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(dailyReviewControllerProvider.notifier);
      if (widget.unitId != null) {
        controller.loadUnitReviewSession(widget.unitId!);
      } else {
        controller.loadSession();
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFlipped || _isDismissing) return;
    HapticFeedback.lightImpact();
    _flipController.forward();
    setState(() {
      _isFlipped = true;
    });
  }

  void _handleResponse(SM2Response response) async {
    if (_isDismissing) return;
    HapticFeedback.mediumImpact();

    // Dismiss direction: hard → left, good/easy → right
    final direction = response == SM2Response.dontKnow ? -1.0 : 1.0;
    setState(() {
      _isDismissing = true;
      _dismissDirection = direction;
    });
    await _dismissController.forward();

    // Advance to next word
    await ref.read(dailyReviewControllerProvider.notifier).answerWord(response);

    // Check if session is complete
    final state = ref.read(dailyReviewControllerProvider);
    if (state.isComplete) {
      _completeSession();
    } else {
      // Reset both controllers instantly for next card
      _dismissController.value = 0;
      _flipController.value = 0;
      setState(() {
        _isFlipped = false;
        _isDismissing = false;
      });
    }
  }

  Future<void> _completeSession() async {
    final state = ref.read(dailyReviewControllerProvider);

    // Unit review: SRS updates already saved per-word in answerWord().
    // Skip the daily review RPC (avoids UNIQUE constraint conflict).
    if (state.isUnitReview) {
      ref.invalidate(todayReviewSessionProvider);
      ref.invalidate(learningPathProvider);
      // Invalidate wordbank providers so Word Bank sees updated review dates
      ref.invalidate(userVocabularyProgressProvider);
      ref.invalidate(learnedWordsWithDetailsProvider);
      if (!mounted) return;
      _showCompletionDialog(state: state, xpEarned: null);
      return;
    }

    // Daily review: record session + earn XP
    final result = await ref
        .read(dailyReviewControllerProvider.notifier)
        .completeSession();

    if (result == null || !mounted) return;

    // Invalidate providers so learning path refreshes (DR node shows as complete)
    ref.invalidate(todayReviewSessionProvider);
    ref.invalidate(learningPathProvider);
    ref.invalidate(dailyQuestProgressProvider); // Refresh daily quest
    // Invalidate wordbank providers so Word Bank sees updated review dates
    ref.invalidate(userVocabularyProgressProvider);
    ref.invalidate(learnedWordsWithDetailsProvider);
    // Refresh user state so XP/coins updates in navbar + triggers level-up
    ref.read(userControllerProvider.notifier).refreshProfileOnly();
    // Invalidate leaderboard so rank reflects new XP
    ref.invalidate(leaderboardDisplayProvider);

    // Re-read state after completeSession updates it
    final updatedState = ref.read(dailyReviewControllerProvider);
    _showCompletionDialog(state: updatedState, xpEarned: result.isNewSession ? result.xpEarned : null, isPerfect: result.isPerfect);
  }

  void _showCompletionDialog({
    required DailyReviewState state,
    int? xpEarned,
    bool isPerfect = false,
  }) {
    final showXp = xpEarned != null && xpEarned > 0;
    // Use first-pass responses only (exclude requeue duplicates)
    final firstPassCount = state.originalWordCount;
    final firstPassResponses = state.responses.take(firstPassCount).toList();
    final easyCount = firstPassResponses.where((r) => r == SM2Response.veryEasy).length;
    final goodCount = firstPassResponses.where((r) => r == SM2Response.gotIt).length;
    final hardCount = firstPassResponses.where((r) => r == SM2Response.dontKnow).length;
    final knownPercent = firstPassCount > 0
        ? ((easyCount + goodCount) / firstPassCount * 100).round()
        : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          isPerfect ? Icons.celebration_rounded : Icons.check_circle_rounded,
          color: isPerfect ? AppColors.streakOrange : AppColors.primary,
          size: 64,
        ),
        title: Text(
          state.isUnitReview
              ? 'Practice Complete!'
              : isPerfect
                  ? 'Perfect Session!'
                  : 'Review Complete!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // XP earned (daily review only)
            if (showXp) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.streakOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.streakOrange, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.streakOrange, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      '+$xpEarned XP',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: AppColors.streakOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Response distribution
            Text(
              'Known: $knownPercent%',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 24),

            _StatRow(emoji: '🚀', label: 'Easy', count: easyCount, color: AppColors.primary),
            _StatRow(emoji: '😊', label: 'Good', count: goodCount, color: AppColors.secondary),
            _StatRow(emoji: '😕', label: 'Hard', count: hardCount, color: AppColors.danger),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: GameButton(
              label: 'Continue',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
                if (!state.isUnitReview) {
                  ref.invalidate(todayReviewSessionProvider);
                  ref.invalidate(dailyReviewWordsProvider);
                }
                ref.read(userControllerProvider.notifier).refreshProfileOnly();
              },
              variant: GameButtonVariant.primary,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyReviewControllerProvider);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.neutralText),
                const SizedBox(height: 16),
                Text(
                  'Could not load words',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  style: GoogleFonts.nunito(color: AppColors.neutralText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GameButton(
                  label: 'Try Again',
                  onPressed: () {
                    final controller = ref.read(dailyReviewControllerProvider.notifier);
                    if (widget.unitId != null) {
                      controller.loadUnitReviewSession(widget.unitId!);
                    } else {
                      controller.loadSession();
                    }
                  },
                  variant: GameButtonVariant.primary,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.words.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'All caught up!',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'No words due for review right now.',
                style: GoogleFonts.nunito(fontSize: 18, color: AppColors.neutralText, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                height: 50,
                child: GameButton(
                  label: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                  variant: GameButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentWord = state.currentWord;
    if (currentWord == null || state.isComplete) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progress = state.originalWordCount > 0
        ? state.uniqueWordsReviewed / state.originalWordCount
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                   GestureDetector(
                     onTap: () => Navigator.of(context).pop(),
                     child: Icon(Icons.close_rounded, color: AppColors.neutralText, size: 32),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: ProProgressBar(progress: progress, height: 20, color: AppColors.streakOrange),
                   ),
                ],
              ),
            ),

            // Stats (optional, hidden or small)

            // Flashcard Pile Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Next card behind active (same size, ready for dismiss reveal)
                    final nextIdx = state.currentIndex + 1;
                    final nextWord = nextIdx < state.words.length
                        ? state.words[nextIdx]
                        : null;

                    return Stack(
                      children: [
                        // Next card — exact same position
                        if (nextWord != null)
                          Positioned.fill(
                            child: _CardFront(word: nextWord),
                          ),

                        // Active card with dismiss + flip
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_flipAnimation, _dismissController]),
                            builder: (context, child) {
                              final dismiss = _dismissController.value;
                              final dir = _dismissDirection;
                              final angle = _flipAnimation.value * math.pi;
                              final isFront = angle < math.pi / 2;

                              return Transform.translate(
                                offset: Offset(
                                  dir * dismiss * constraints.maxWidth * 0.8,
                                  dismiss * constraints.maxHeight * 0.3,
                                ),
                                child: Transform.rotate(
                                  angle: dir * dismiss * 0.3,
                                  child: Opacity(
                                    opacity: (1.0 - dismiss * 1.5).clamp(0.0, 1.0),
                                    child: GestureDetector(
                                      onTap: _flipCard,
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateY(angle),
                                        child: isFront
                                            ? _CardFront(word: currentWord)
                                            : Transform(
                                                alignment: Alignment.center,
                                                transform: Matrix4.identity()..rotateY(math.pi),
                                                child: _CardBack(word: currentWord),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
  
            // Bottom area — fixed height so card doesn't resize on flip
            SizedBox(
              height: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hint text (before flip)
                    AnimatedOpacity(
                      opacity: _isFlipped ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        'Tap card to reveal answer',
                        style: GoogleFonts.nunito(
                          color: AppColors.neutralText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Question + buttons (after flip)
                    AnimatedOpacity(
                      opacity: _isFlipped ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_isFlipped,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Is this word easy or hard for you?',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutralText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: GameButton(label: '😕 Hard', variant: GameButtonVariant.danger, onPressed: () => _handleResponse(SM2Response.dontKnow))),
                                const SizedBox(width: 12),
                                Expanded(child: GameButton(label: '😊 Good', variant: GameButtonVariant.secondary, onPressed: () => _handleResponse(SM2Response.gotIt))),
                                const SizedBox(width: 12),
                                Expanded(child: GameButton(label: '🚀 Easy', variant: GameButtonVariant.primary, onPressed: () => _handleResponse(SM2Response.veryEasy))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word});

  final VocabularyWord word;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1CB0F6), Color(0xFF1278A8)],
  );
  static const _qColor = Color(0x59FFFFFF); // white 35%
  static const _frameColor = Color(0x33FFFFFF); // white 20%

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.neutral, offset: Offset(0, 8)),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Top-left "?"
            Positioned(
              top: 0,
              left: 0,
              child: Text('?', style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900, color: _qColor)),
            ),
            // Bottom-right "?" (rotated)
            Positioned(
              bottom: 0,
              right: 0,
              child: Transform.rotate(
                angle: math.pi,
                child: Text('?', style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900, color: _qColor)),
              ),
            ),
            // Inner decorative frame + word
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _frameColor, width: 2),
                ),
                child: Text(
                  word.word,
                  style: GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.word});

  final VocabularyWord word;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.neutral, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Banner — sadece Türkçe anlam
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: AppColors.secondary,
                child: Text(
                  word.meaningTR,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Image area (contained, white bg)
              if (word.hasImage)
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: AppColors.white,
                    child: Image.network(
                      word.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

              // Info sections
              Expanded(
                flex: word.hasImage ? 2 : 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoSection(label: 'Definition', content: word.meaningEN ?? word.meaningTR, icon: Icons.menu_book_rounded, color: AppColors.primary),
                        if (word.exampleSentences.isNotEmpty)
                          _InfoSection(label: 'Example', content: word.exampleSentences.first, icon: Icons.format_quote_rounded, color: AppColors.gemBlue),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Word label — bottom-right, card name style
          Positioned(
            bottom: 12,
            right: 18,
            child: Text(
              word.word,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.label,
    required this.content,
    required this.icon,
    required this.color,
  });

  final String label;
  final String content;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.nunito(fontSize: 18, color: AppColors.black, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  final String emoji;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.black)),
          const Spacer(),
          Text(
            '$count',
            style: GoogleFonts.nunito(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
