import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/entities/vocabulary.dart';
import '../../../providers/vocabulary_provider.dart';

/// Phase 1: Learn Vocab
/// Grid view showing all words with images, audio, and definitions
class Phase1LearnScreen extends ConsumerStatefulWidget {

  const Phase1LearnScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<Phase1LearnScreen> createState() => _Phase1LearnScreenState();
}

class _Phase1LearnScreenState extends ConsumerState<Phase1LearnScreen> {
  int _currentIndex = 0;
  bool _showDefinition = false;

  @override
  Widget build(BuildContext context) {
    final wordListAsync = ref.watch(wordListByIdProvider(widget.listId));
    final wordsAsync = ref.watch(wordsForListProvider(widget.listId));

    final wordList = wordListAsync.valueOrNull;
    final words = wordsAsync.valueOrNull ?? [];

    if (wordsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learn Vocab')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learn Vocab')),
        body: const Center(child: Text('No words in this list')),
      );
    }

    final currentWord = words[_currentIndex];
    final progress = (_currentIndex + 1) / words.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(wordList?.name ?? 'Learn Vocab'),
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
          ),

          // Word card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _WordCard(
                word: currentWord,
                showDefinition: _showDefinition,
                onToggleDefinition: () {
                  setState(() => _showDefinition = !_showDefinition);
                },
              ),
            ),
          ),

          // Navigation buttons
          _NavigationBar(
            currentIndex: _currentIndex,
            totalCount: words.length,
            onPrevious: _currentIndex > 0
                ? () => setState(() {
                      _currentIndex--;
                      _showDefinition = false;
                    })
                : null,
            onNext: _currentIndex < words.length - 1
                ? () => setState(() {
                      _currentIndex++;
                      _showDefinition = false;
                    })
                : null,
            onComplete: _currentIndex == words.length - 1
                ? () => _completePhase(context)
                : null,
          ),
        ],
      ),
    );
  }

  void _completePhase(BuildContext context) {
    // Mark phase as complete
    ref.read(wordListProgressControllerProvider.notifier)
        .completePhase(widget.listId, 1);

    // Show completion dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Phase 1 Complete!'),
        content: const Text(
          'Great job! You\'ve reviewed all the words.\n\n'
          'Ready for the Spelling phase?',
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
              // Navigate to phase 2
              context.pushReplacement('/vocabulary/list/${widget.listId}/phase/2');
            },
            child: const Text('Continue to Spelling'),
          ),
        ],
      ),
    );
  }
}

/// Card showing word details
class _WordCard extends StatelessWidget {

  const _WordCard({
    required this.word,
    required this.showDefinition,
    required this.onToggleDefinition,
  });
  final VocabularyWord word;
  final bool showDefinition;
  final VoidCallback onToggleDefinition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Word image placeholder
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: word.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      word.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ImagePlaceholder(word: word),
                    ),
                  )
                : _ImagePlaceholder(word: word),
          ),
        ),
        const SizedBox(height: 16),

        // Word with audio button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                word.word,
                style: context.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                // TODO: Play audio
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Audio playback coming soon!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.volume_up),
            ),
          ],
        ),

        // Phonetic
        if (word.phonetic != null) ...[
          const SizedBox(height: 4),
          Text(
            word.phonetic!,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Part of speech
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              word.level ?? 'Word',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Definition toggle
        GestureDetector(
          onTap: onToggleDefinition,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: showDefinition
                  ? context.colorScheme.surfaceContainerHighest
                  : context.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: showDefinition
                    ? context.colorScheme.outline.withValues(alpha: 0.2)
                    : context.colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: showDefinition
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Definition
                      Text(
                        'Definition',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        word.meaningEN ?? word.meaningTR,
                        style: context.textTheme.bodyLarge,
                      ),

                      // Turkish translation
                      const SizedBox(height: 16),
                      Text(
                        'Türkçe',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        word.meaningTR,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      // Example sentences
                      if (word.exampleSentences.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Examples',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...word.exampleSentences.map((sentence) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $sentence',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),),
                      ],

                      // Synonyms & Antonyms
                      if (word.synonyms.isNotEmpty ||
                          word.antonyms.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (word.synonyms.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Synonyms',
                                      style:
                                          context.textTheme.labelMedium?.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children: word.synonyms
                                          .map((s) => Chip(
                                                label: Text(s),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                backgroundColor: Colors.green
                                                    .withValues(alpha: 0.1),
                                              ),)
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            if (word.antonyms.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Antonyms',
                                      style:
                                          context.textTheme.labelMedium?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children: word.antonyms
                                          .map((a) => Chip(
                                                label: Text(a),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                backgroundColor: Colors.red
                                                    .withValues(alpha: 0.1),
                                              ),)
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to see definition',
                        style: context.textTheme.titleMedium?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {

  const _ImagePlaceholder({required this.word});
  final VocabularyWord word;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 64,
            color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            word.word,
            style: context.textTheme.headlineSmall?.copyWith(
              color: context.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom navigation bar
class _NavigationBar extends StatelessWidget {

  const _NavigationBar({
    required this.currentIndex,
    required this.totalCount,
    this.onPrevious,
    this.onNext,
    this.onComplete,
  });
  final int currentIndex;
  final int totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Previous button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 16),

            // Next/Complete button
            Expanded(
              child: onComplete != null
                  ? FilledButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
