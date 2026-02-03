import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/sm2_algorithm.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../providers/daily_review_provider.dart';

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
        icon: Icon(
          result.isPerfect ? Icons.celebration : Icons.check_circle,
          color: result.isPerfect ? Colors.orange : Colors.green,
          size: 48,
        ),
        title: Text(result.isPerfect ? 'Perfect Session!' : 'Review Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // XP earned
            if (result.isNewSession) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '+${result.xpEarned} XP',
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Stats
            Text(
              'Accuracy: $accuracyPercent%',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _StatRow(
              emoji: '✅',
              label: 'Correct',
              count: state.correctCount,
              color: Colors.green,
            ),
            _StatRow(
              emoji: '❌',
              label: 'Incorrect',
              count: state.incorrectCount,
              color: Colors.red,
            ),
            _StatRow(
              emoji: '📚',
              label: 'Total Reviewed',
              count: state.totalReviewed,
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            if (!result.isNewSession)
              Text(
                'You already completed today\'s review.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.outline,
                ),
              )
            else
              Text(
                result.isPerfect
                    ? 'Amazing! You nailed every word!'
                    : 'Great job! Keep practicing to improve.',
                style: context.textTheme.bodyMedium,
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
              // Invalidate providers to refresh hub
              ref.invalidate(todayReviewSessionProvider);
              ref.invalidate(dailyReviewWordsProvider);
            },
            child: const Text('Back to Vocabulary'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyReviewControllerProvider);

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Review')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'All caught up!',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No words due for review right now.',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Vocabulary'),
              ),
            ],
          ),
        ),
      );
    }

    final currentWord = state.currentWord;
    if (currentWord == null || state.isComplete) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progress = (state.currentIndex + 1) / state.words.length;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Daily Review'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${state.currentIndex + 1}/${state.words.length}',
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
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniStat(
                  emoji: '✅',
                  count: state.correctCount,
                  color: Colors.green,
                ),
                const SizedBox(width: 24),
                _MiniStat(
                  emoji: '❌',
                  count: state.incorrectCount,
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Flashcard
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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

          // Tap to flip hint
          if (!_isFlipped)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tap card to reveal answer',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
            ),

          // Response buttons (only show when flipped)
          AnimatedOpacity(
            opacity: _isFlipped ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedSlide(
              offset: _isFlipped ? Offset.zero : const Offset(0, 0.5),
              duration: const Duration(milliseconds: 200),
              child: _ResponseButtons(
                onResponse: _isFlipped ? _handleResponse : null,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.emoji,
    required this.count,
    required this.color,
  });

  final String emoji;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word});

  final VocabularyWord word;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Word
            Text(
              word.word,
              style: context.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // Phonetic
            if (word.phonetic != null) ...[
              const SizedBox(height: 8),
              Text(
                word.phonetic!,
                style: context.textTheme.titleLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Part of speech or level
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                word.partOfSpeech ?? word.level ?? 'Word',
                style: context.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Audio button
            IconButton.filled(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔊 "${word.word}"'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.volume_up),
              iconSize: 32,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
              ),
            ),

            const Spacer(),

            // Flip hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap to flip',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
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
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word header
              Center(
                child: Text(
                  word.word,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Definition
              _InfoSection(
                label: 'Definition',
                content: word.meaningEN ?? word.meaningTR,
                icon: Icons.menu_book,
              ),

              // Turkish meaning
              _InfoSection(
                label: 'Türkçe',
                content: word.meaningTR,
                icon: Icons.translate,
              ),

              // Example sentences
              if (word.exampleSentences.isNotEmpty)
                _InfoSection(
                  label: 'Examples',
                  content: word.exampleSentences.join('\n'),
                  icon: Icons.format_quote,
                ),

              // Synonyms
              if (word.synonyms.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Synonyms',
                  style: context.textTheme.labelLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: word.synonyms
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                        ),
                      )
                      .toList(),
                ),
              ],

              // Antonyms
              if (word.antonyms.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Antonyms',
                  style: context.textTheme.labelLarge?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: word.antonyms
                      .map(
                        (a) => Chip(
                          label: Text(a),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
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
  });

  final String label;
  final String content;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ResponseButtons extends StatelessWidget {
  const _ResponseButtons({this.onResponse});

  final void Function(SM2Response)? onResponse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Don't know
          Expanded(
            child: _ResponseButton(
              emoji: '😕',
              label: "I don't know!",
              color: Colors.red,
              onPressed: onResponse != null
                  ? () => onResponse!(SM2Response.dontKnow)
                  : null,
            ),
          ),
          const SizedBox(width: 8),

          // Got it
          Expanded(
            child: _ResponseButton(
              emoji: '😊',
              label: 'Got it!',
              color: Colors.blue,
              onPressed:
                  onResponse != null ? () => onResponse!(SM2Response.gotIt) : null,
            ),
          ),
          const SizedBox(width: 8),

          // Very easy
          Expanded(
            child: _ResponseButton(
              emoji: '🚀',
              label: 'Very EASY!',
              color: Colors.green,
              onPressed: onResponse != null
                  ? () => onResponse!(SM2Response.veryEasy)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.emoji,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
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
