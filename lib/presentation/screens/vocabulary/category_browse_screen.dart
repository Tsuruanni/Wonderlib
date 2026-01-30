import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';

/// Screen to browse word lists in a specific category
class CategoryBrowseScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryBrowseScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = _parseCategory(categoryName);

    if (category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Category not found')),
      );
    }

    final lists = ref.watch(wordListsByCategoryProvider(category));

    return Scaffold(
      appBar: AppBar(
        title: Text(category.displayName),
      ),
      body: lists.isEmpty
          ? _EmptyState(category: category)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                final progress = ref.watch(progressForListProvider(list.id));
                return _WordListCard(
                  wordList: list,
                  progress: progress,
                );
              },
            ),
    );
  }

  WordListCategory? _parseCategory(String name) {
    try {
      return WordListCategory.values.firstWhere(
        (c) => c.name == name,
      );
    } catch (_) {
      return null;
    }
  }
}

class _WordListCard extends StatelessWidget {
  final WordList wordList;
  final UserWordListProgress? progress;

  const _WordListCard({
    required this.wordList,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/vocabulary/list/${wordList.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getCategoryColor(wordList.category).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    wordList.category.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Title and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wordList.name,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${wordList.wordCount} words${wordList.level != null ? ' • ${wordList.level}' : ''}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress!.progressPercentage,
                          minHeight: 6,
                          backgroundColor: context.colorScheme.outline.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getCategoryColor(wordList.category),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status icon
              if (progress?.isFullyComplete ?? false)
                const Icon(Icons.check_circle, color: Colors.green)
              else
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

class _EmptyState extends StatelessWidget {
  final WordListCategory category;

  const _EmptyState({required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 64),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No lists in ${category.displayName}',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new word lists!',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
