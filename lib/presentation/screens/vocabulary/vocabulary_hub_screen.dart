import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/vocabulary_provider.dart';

/// Main vocabulary hub screen with word lists organized by sections
class VocabularyHubScreen extends ConsumerWidget {
  const VocabularyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueLearningAsync = ref.watch(continueWordListsProvider);
    final recommendedAsync = ref.watch(recommendedWordListsProvider);
    final storyListsAsync = ref.watch(storyWordListsProvider);
    final hubStatsAsync = ref.watch(vocabularyHubStatsProvider);

    // Extract values with defaults
    final continueLeaning = continueLearningAsync.valueOrNull ?? [];
    final recommended = recommendedAsync.valueOrNull ?? [];
    final storyLists = storyListsAsync.valueOrNull ?? [];
    final hubStats = hubStatsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        actions: [
          // Stats chip
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.star, size: 18),
              label: Text('${hubStats?.masteredWords ?? 0} mastered'),
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Daily Review Section (always first and prominent)
          const _DailyReviewSection(),

          // Continue Learning section
          if (continueLeaning.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Continue Learning',
              icon: Icons.play_circle_outline,
            ),
            _HorizontalListSection(lists: continueLeaning),
          ],

          // Recommended section
          if (recommended.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Recommended for You',
              icon: Icons.star_outline,
            ),
            _HorizontalListSection(lists: recommended),
          ],

          // My Word Lists (story vocabulary)
          if (storyLists.isNotEmpty) ...[
            const _SectionHeader(
              title: 'My Word Lists',
              icon: Icons.bookmark_outline,
            ),
            _VerticalListSection(lists: storyLists, ref: ref),
          ],

          // Explore Categories
          const _SectionHeader(
            title: 'Explore Categories',
            icon: Icons.category_outlined,
          ),
          const _CategoriesGrid(),

          // Empty state if nothing to show
          if (continueLeaning.isEmpty && recommended.isEmpty && storyLists.isEmpty)
            _EmptyState(),
        ],
      ),
    );
  }
}

/// Daily Review Section with 3 states: completed, no words, ready
class _DailyReviewSection extends ConsumerWidget {
  const _DailyReviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySessionAsync = ref.watch(todayReviewSessionProvider);
    final dueWordsAsync = ref.watch(dailyReviewWordsProvider);

    final todaySession = todaySessionAsync.valueOrNull;
    final dueWords = dueWordsAsync.valueOrNull ?? [];

    // State 1: Already completed today
    if (todaySession != null) {
      return _CompletedReviewCard(session: todaySession);
    }

    // State 2: No words due
    if (dueWords.isEmpty) {
      return const _AllCaughtUpCard();
    }

    // State 3: Words ready for review
    return _ReadyToReviewCard(wordCount: dueWords.length);
  }
}

/// Card showing completed review session
class _CompletedReviewCard extends StatelessWidget {
  const _CompletedReviewCard({required this.session});

  final dynamic session; // DailyReviewSession

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.green.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Review Complete!",
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+${session.xpEarned} XP earned',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (session.isPerfect)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Perfect',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Card showing no words due
class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.emoji_events,
              color: Colors.blue.shade400,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Caught Up!',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No words due for review. Keep learning!',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing words ready for review
class _ReadyToReviewCard extends StatelessWidget {
  const _ReadyToReviewCard({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.flash_on,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Review',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$wordCount words ready for review',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              context.push('/vocabulary/daily-review');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange.shade700,
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

/// Section header with icon and title
class _SectionHeader extends StatelessWidget {

  const _SectionHeader({
    required this.title,
    required this.icon,
  });
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling list of word list cards
class _HorizontalListSection extends StatelessWidget {

  const _HorizontalListSection({required this.lists});
  final List<WordListWithProgress> lists;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _WordListCard(listWithProgress: lists[index]);
        },
      ),
    );
  }
}

/// Vertical list of word list items
class _VerticalListSection extends StatelessWidget {

  const _VerticalListSection({required this.lists, required this.ref});
  final List<WordList> lists;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: lists.map((list) {
          final progressAsync = ref.watch(progressForListProvider(list.id));
          return _WordListTile(
            wordList: list,
            progress: progressAsync.valueOrNull,
          );
        }).toList(),
      ),
    );
  }
}

/// Card widget for a word list (used in horizontal scroll)
class _WordListCard extends StatelessWidget {

  const _WordListCard({required this.listWithProgress});
  final WordListWithProgress listWithProgress;

  @override
  Widget build(BuildContext context) {
    final list = listWithProgress.wordList;
    final progress = listWithProgress.progress;

    return GestureDetector(
      onTap: () {
        context.push('/vocabulary/list/${list.id}');
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getCategoryColor(list.category).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                list.category.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              list.name,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Word count and level
            Text(
              '${list.wordCount} words${list.level != null ? ' • ${list.level}' : ''}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),

            const Spacer(),

            // Progress bar
            if (progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.progressPercentage,
                  minHeight: 6,
                  backgroundColor: context.colorScheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCategoryColor(list.category),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress.progressPercentage * 100).toInt()}% complete',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
            ] else
              Text(
                'Not started',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
          ],
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

/// Tile widget for word list (used in vertical list)
class _WordListTile extends StatelessWidget {

  const _WordListTile({
    required this.wordList,
    this.progress,
  });
  final WordList wordList;
  final UserWordListProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          context.push('/vocabulary/list/${wordList.id}');
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            wordList.category.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          wordList.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${wordList.wordCount} words'),
        trailing: progress != null
            ? _buildProgressIndicator(context, progress!)
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, UserWordListProgress progress) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.progressPercentage,
            strokeWidth: 4,
            backgroundColor: context.colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.isFullyComplete ? Colors.green : context.colorScheme.primary,
            ),
          ),
          Text(
            '${(progress.progressPercentage * 100).toInt()}%',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling category cards (same size as word list cards)
class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      WordListCategory.commonWords,
      WordListCategory.gradeLevel,
      WordListCategory.testPrep,
      WordListCategory.thematic,
    ];

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final listsAsync = ref.watch(wordListsByCategoryProvider(category));
          return _CategoryCard(
            category: category,
            listCount: listsAsync.valueOrNull?.length ?? 0,
          );
        },
      ),
    );
  }
}

/// Card for a category (fixed width like word list cards)
class _CategoryCard extends StatelessWidget {

  const _CategoryCard({
    required this.category,
    required this.listCount,
  });
  final WordListCategory category;
  final int listCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/vocabulary/category/${category.name}');
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getCategoryColor(category),
              _getCategoryColor(category).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const Spacer(),
            Text(
              category.displayName,
              style: context.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$listCount lists',
              style: context.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
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

/// Empty state when no lists available
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No word lists yet',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start reading stories to build your vocabulary!',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.go('/library');
            },
            icon: const Icon(Icons.menu_book),
            label: const Text('Browse Library'),
          ),
        ],
      ),
    );
  }
}
