import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';

/// Detail screen for a word list showing phases and progress
class WordListDetailScreen extends ConsumerWidget {

  const WordListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListAsync = ref.watch(wordListByIdProvider(listId));
    final progress = ref.watch(wordListProgressProvider(listId));
    final wordsAsync = ref.watch(wordsForListProvider(listId));

    // Handle loading state
    if (wordListAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final wordList = wordListAsync.valueOrNull;
    final words = wordsAsync.valueOrNull ?? [];

    if (wordList == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Word list not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with cover
          _ListHeader(wordList: wordList, progress: progress),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    wordList.description,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.library_books,
                        label: '${words.length} words',
                      ),
                      const SizedBox(width: 8),
                      if (wordList.level != null)
                        _StatChip(
                          icon: Icons.signal_cellular_alt,
                          label: wordList.level!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Learning Phases section
                  Text(
                    'Learning Phases',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phase cards
                  _PhaseCard(
                    phase: 1,
                    title: 'Learn Vocab',
                    description: 'See all words with meanings and images',
                    icon: Icons.visibility,
                    color: Colors.blue,
                    isComplete: progress?.phase1Complete ?? false,
                    isRecommended: progress == null || (!progress.phase1Complete),
                    onTap: () => _navigateToPhase(context, 1),
                  ),
                  _PhaseCard(
                    phase: 2,
                    title: 'Spelling',
                    description: 'Practice spelling by listening',
                    icon: Icons.keyboard,
                    color: Colors.purple,
                    isComplete: progress?.phase2Complete ?? false,
                    isRecommended: (progress?.phase1Complete ?? false) &&
                                   progress?.phase2Complete != true,
                    onTap: () => _navigateToPhase(context, 2),
                  ),
                  _PhaseCard(
                    phase: 3,
                    title: 'Flashcards',
                    description: 'Test yourself with flip cards',
                    icon: Icons.flip,
                    color: Colors.orange,
                    isComplete: progress?.phase3Complete ?? false,
                    isRecommended: (progress?.phase2Complete ?? false) &&
                                   progress?.phase3Complete != true,
                    onTap: () => _navigateToPhase(context, 3),
                  ),
                  _PhaseCard(
                    phase: 4,
                    title: 'Review',
                    description: 'Quiz to check your knowledge',
                    icon: Icons.quiz,
                    color: Colors.green,
                    isComplete: progress?.phase4Complete ?? false,
                    isRecommended: (progress?.phase3Complete ?? false) &&
                                   progress?.phase4Complete != true,
                    onTap: () => _navigateToPhase(context, 4),
                    score: progress?.phase4Score,
                    total: progress?.phase4Total,
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, progress),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFAB(BuildContext context, UserWordListProgress? progress) {
    final nextPhase = progress?.nextPhase ?? 1;
    final isComplete = progress?.isFullyComplete ?? false;

    if (isComplete) {
      return FloatingActionButton.extended(
        onPressed: () => _navigateToPhase(context, 1),
        icon: const Icon(Icons.replay),
        label: const Text('Practice Again'),
        backgroundColor: Colors.green,
      );
    }

    final phaseNames = ['', 'Learn Vocab', 'Spelling', 'Flashcards', 'Review'];
    return FloatingActionButton.extended(
      onPressed: () => _navigateToPhase(context, nextPhase),
      icon: Icon(progress == null ? Icons.play_arrow : Icons.play_circle),
      label: Text(progress == null ? 'Start Learning' : 'Continue: ${phaseNames[nextPhase]}'),
    );
  }

  void _navigateToPhase(BuildContext context, int phase) {
    context.push('/vocabulary/list/$listId/phase/$phase');
  }
}

/// Header with gradient and list info
class _ListHeader extends StatelessWidget {

  const _ListHeader({
    required this.wordList,
    this.progress,
  });
  final WordList wordList;
  final UserWordListProgress? progress;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 48, right: 16, bottom: 16),
        title: Text(
          wordList.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getCategoryColor(wordList.category),
                _getCategoryColor(wordList.category).withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Category emoji background
              Positioned(
                right: -20,
                bottom: -20,
                child: Text(
                  wordList.category.icon,
                  style: TextStyle(
                    fontSize: 150,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),

              // Progress indicator at top area (safe from title collision)
              if (progress != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress!.progressPercentage,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress!.progressPercentage * 100).toInt()}% complete • ${progress!.completedPhases}/4 phases',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(WordListCategory category) {
    switch (category) {
      case WordListCategory.commonWords:
        return Colors.blue;
      case WordListCategory.gradeLevel:
        return Colors.purple;
      case WordListCategory.testPrep:
        return Colors.orange;
      case WordListCategory.thematic:
        return Colors.teal;
      case WordListCategory.storyVocab:
        return Colors.pink;
    }
  }
}

/// Small stat chip
class _StatChip extends StatelessWidget {

  const _StatChip({
    required this.icon,
    required this.label,
  });
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Card for a learning phase
class _PhaseCard extends StatelessWidget {

  const _PhaseCard({
    required this.phase,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isComplete,
    required this.isRecommended,
    required this.onTap,
    this.score,
    this.total,
  });
  final int phase;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isComplete;
  final bool isRecommended;
  final VoidCallback onTap;
  final int? score;
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Phase number with icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.green.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isComplete
                    ? const Icon(Icons.check, color: Colors.green, size: 28)
                    : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),

              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$phase. $title',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended && !isComplete) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Next',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    // Show score for Review phase
                    if (score != null && total != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Score: $score/$total',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: context.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
