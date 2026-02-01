import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../core/utils/sm2_algorithm.dart';
import '../../../../domain/entities/vocabulary.dart';
import '../../../providers/vocabulary_provider.dart';

/// Phase 3: Flashcards
/// Flip cards with SM-2 spaced repetition algorithm
class Phase3FlashcardsScreen extends ConsumerStatefulWidget {

  const Phase3FlashcardsScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<Phase3FlashcardsScreen> createState() =>
      _Phase3FlashcardsScreenState();
}

class _Phase3FlashcardsScreenState extends ConsumerState<Phase3FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  List<VocabularyWord> _words = [];

  // Stats
  int _dontKnowCount = 0;
  int _gotItCount = 0;
  int _veryEasyCount = 0;

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

  void _handleResponse(SM2Response response) {
    HapticFeedback.mediumImpact();

    setState(() {
      switch (response) {
        case SM2Response.dontKnow:
          _dontKnowCount++;
        case SM2Response.gotIt:
          _gotItCount++;
        case SM2Response.veryEasy:
          _veryEasyCount++;
      }
    });

    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _words.length - 1) {
      // Reset flip state
      if (_isFlipped) {
        _flipController.reverse();
        setState(() => _isFlipped = false);
      }

      // Short delay then advance
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _currentIndex++;
          });
        }
      });
    } else {
      _completePhase();
    }
  }

  void _completePhase() {
    final total = _dontKnowCount + _gotItCount + _veryEasyCount;
    final masteryRate =
        total > 0 ? ((_gotItCount + _veryEasyCount) / total * 100).round() : 0;

    // Mark phase as complete
    ref.read(wordListProgressControllerProvider.notifier)
        .completePhase(widget.listId, 3);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          masteryRate >= 70 ? Icons.celebration : Icons.school,
          color: masteryRate >= 70 ? Colors.orange : Colors.blue,
          size: 48,
        ),
        title: const Text('Phase 3 Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mastery Rate: $masteryRate%',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _StatRow(
              emoji: '😕',
              label: "I don't know",
              count: _dontKnowCount,
              color: Colors.red,
            ),
            _StatRow(
              emoji: '😊',
              label: 'Got it',
              count: _gotItCount,
              color: Colors.blue,
            ),
            _StatRow(
              emoji: '🚀',
              label: 'Very EASY',
              count: _veryEasyCount,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              masteryRate >= 70
                  ? 'Great job! Ready for the final quiz!'
                  : 'Consider reviewing again to improve retention.',
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to List'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate to phase 4
              context.pushReplacement('/vocabulary/list/${widget.listId}/phase/4');
            },
            child: const Text('Continue to Review'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordListAsync = ref.watch(wordListByIdProvider(widget.listId));
    final wordsAsync = ref.watch(wordsForListProvider(widget.listId));

    final wordList = wordListAsync.valueOrNull;
    final words = wordsAsync.valueOrNull ?? [];

    if (wordsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(child: Text('No words in this list')),
      );
    }

    // Cache words for use in methods
    if (_words.isEmpty) {
      _words = words;
    }

    final currentWord = words[_currentIndex];
    final progress = (_currentIndex + 1) / words.length;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(wordList?.name ?? 'Flashcards'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${words.length}',
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
                _MiniStat(emoji: '😕', count: _dontKnowCount, color: Colors.red),
                const SizedBox(width: 24),
                _MiniStat(emoji: '😊', count: _gotItCount, color: Colors.blue),
                const SizedBox(width: 24),
                _MiniStat(
                    emoji: '🚀', count: _veryEasyCount, color: Colors.green,),
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
              Colors.orange.shade400,
              Colors.orange.shade600,
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

            // Part of speech
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                word.level ?? 'Word',
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
                    color: Colors.orange,
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
                      .map((s) => Chip(
                            label: Text(s),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                          ),)
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
                      .map((a) => Chip(
                            label: Text(a),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                          ),)
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
              onPressed:
                  onResponse != null ? () => onResponse!(SM2Response.dontKnow) : null,
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
              onPressed:
                  onResponse != null ? () => onResponse!(SM2Response.veryEasy) : null,
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
