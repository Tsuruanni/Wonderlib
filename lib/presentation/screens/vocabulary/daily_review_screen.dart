import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/sm2_algorithm.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../providers/daily_review_provider.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/pro_progress_bar.dart';

/// Daily Review Screen - Anki-style spaced repetition flashcards
class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

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

    // Load session on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyReviewControllerProvider.notifier).loadSession();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _handleResponse(SM2Response response) async {
     HapticFeedback.mediumImpact();

    // Answer and advance
    await ref.read(dailyReviewControllerProvider.notifier).answerWord(response);

    // Check if session is complete
    final state = ref.read(dailyReviewControllerProvider);
    if (state.isComplete) {
      _completeSession();
    } else {
      // Reset flip state for next card
      if (_isFlipped) {
        _flipController.reverse();
        setState(() => _isFlipped = false);
      }
    }
  }

  Future<void> _completeSession() async {
    final result = await ref
        .read(dailyReviewControllerProvider.notifier)
        .completeSession();

    if (result == null || !mounted) return;

    final state = ref.read(dailyReviewControllerProvider);
    final accuracyPercent = (state.accuracy * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          result.isPerfect ? Icons.celebration_rounded : Icons.check_circle_rounded,
          color: result.isPerfect ? AppColors.streakOrange : AppColors.primary,
          size: 64,
        ),
        title: Text(
          result.isPerfect ? 'Perfect Session!' : 'Review Complete!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // XP earned
            if (result.isNewSession) ...[
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
                      '+${result.xpEarned} XP',
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

            // Stats
            Text(
              'Accuracy: $accuracyPercent%',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 24),

            _StatRow(emoji: '✅', label: 'Correct', count: state.correctCount, color: AppColors.primary),
            _StatRow(emoji: '❌', label: 'Incorrect', count: state.incorrectCount, color: AppColors.danger),
            _StatRow(emoji: '📚', label: 'Total', count: state.totalReviewed, color: AppColors.secondary),
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
                ref.invalidate(todayReviewSessionProvider);
                ref.invalidate(dailyReviewWordsProvider);
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

    final progress = (state.currentIndex + 1) / state.words.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
            
            // Flashcard Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * math.pi;
                      final isFront = angle < math.pi / 2;
  
                      return Transform(
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
                      );
                    },
                  ),
                ),
              ),
            ),
  
            // Hint text
            if (!_isFlipped)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Tap card to reveal answer',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
  
            // Response buttons
             Container(
               height: 100, // Fixed height for buttons area
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
               child: AnimatedOpacity(
                  opacity: _isFlipped ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_isFlipped,
                    child: Row(
                      children: [
                        Expanded(child: GameButton(label: '😕 Hard', variant: GameButtonVariant.danger, onPressed: () => _handleResponse(SM2Response.dontKnow))),
                        const SizedBox(width: 12),
                        Expanded(child: GameButton(label: '😊 Good', variant: GameButtonVariant.secondary, onPressed: () => _handleResponse(SM2Response.gotIt))),
                        const SizedBox(width: 12),
                        Expanded(child: GameButton(label: '🚀 Easy', variant: GameButtonVariant.primary, onPressed: () => _handleResponse(SM2Response.veryEasy))),
                      ],
                    ),
                  ),
               ),
             ),
             const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word});

  final VocabularyWord word;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
           BoxShadow(color: AppColors.neutral, offset: Offset(0, 8)),
        ]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: GoogleFonts.nunito(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
            ),
            textAlign: TextAlign.center,
          ),
          if (word.phonetic != null) ...[
            const SizedBox(height: 8),
            Text(
              word.phonetic!,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.neutralText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             decoration: BoxDecoration(color: AppColors.gemBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
             child: Text(
               word.partOfSpeech ?? word.level ?? 'Word',
               style: GoogleFonts.nunito(color: AppColors.gemBlue, fontWeight: FontWeight.bold),
             ),
          ),
          const SizedBox(height: 48),
          IconButton(
             onPressed: () {
                HapticFeedback.lightImpact();
                // Audio logic would go here
             },
             icon: Icon(Icons.volume_up_rounded, size: 40, color: AppColors.secondary),
             style: IconButton.styleFrom(
               backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
               padding: EdgeInsets.all(16),
             ),
          ),
        ],
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
         border: Border.all(color: AppColors.neutral, width: 2),
         boxShadow: [
            BoxShadow(color: AppColors.neutral, offset: Offset(0, 8)),
         ]
      ),
      child: SingleChildScrollView(
        child: Column(
            children: [
               Text(
                 word.word,
                 style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.secondary),
               ),
               Divider(height: 32, thickness: 2, color: AppColors.neutral),
               _InfoSection(label: 'Definition', content: word.meaningEN ?? word.meaningTR, icon: Icons.menu_book_rounded, color: AppColors.primary),
               if (word.meaningTR != word.meaningEN)
                 _InfoSection(label: 'Türkçe', content: word.meaningTR, icon: Icons.translate_rounded, color: AppColors.streakOrange),
               if (word.exampleSentences.isNotEmpty)
                 _InfoSection(label: 'Example', content: word.exampleSentences.first, icon: Icons.format_quote_rounded, color: AppColors.gemBlue),
            ],
        ),
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
