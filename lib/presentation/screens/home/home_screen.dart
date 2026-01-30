import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/vocabulary_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadEng'),
        actions: [
          // Profile button
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 20),
            ),
            onPressed: () => context.push(AppRoutes.profile),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome header
                Text(
                  'Welcome back, ${user.firstName}!',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep up your reading streak!',
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.star,
                      label: 'XP',
                      value: user.xp.toString(),
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.local_fire_department,
                      label: 'Streak',
                      value: '${user.currentStreak} days',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.trending_up,
                      label: 'Level',
                      value: user.level.toString(),
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Daily Tasks
                const _DailyTasksSection(),
                const SizedBox(height: 24),

                // Continue Reading
                _ContinueReadingSection(),
                const SizedBox(height: 24),

                // Recommended Books
                _RecommendedBooksSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DailyTasksSection extends ConsumerWidget {
  const _DailyTasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueWords = ref.watch(wordsDueForReviewProvider);

    // Daily tasks data
    final tasks = [
      _DailyTask(
        icon: Icons.menu_book,
        title: 'Read for 10 minutes',
        progress: 0.6, // Mock: 6/10 minutes
        progressText: '6/10 min',
        color: Colors.blue,
        isComplete: false,
      ),
      _DailyTask(
        icon: Icons.abc,
        title: 'Review vocabulary',
        progress: dueWords.isEmpty ? 1.0 : 0.0,
        progressText: dueWords.isEmpty ? 'Done' : '${dueWords.length} words',
        color: Colors.purple,
        isComplete: dueWords.isEmpty,
      ),
      _DailyTask(
        icon: Icons.quiz,
        title: 'Complete an activity',
        progress: 1.0, // Mock: completed
        progressText: 'Done',
        color: Colors.green,
        isComplete: true,
      ),
    ];

    final completedCount = tasks.where((t) => t.isComplete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Tasks',
              style: context.textTheme.titleLarge,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: completedCount == tasks.length
                    ? Colors.green.withValues(alpha: 0.2)
                    : context.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$completedCount/${tasks.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: completedCount == tasks.length
                      ? Colors.green
                      : context.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tasks.map((task) => _DailyTaskCard(task: task)),
      ],
    );
  }
}

class _DailyTask {
  final IconData icon;
  final String title;
  final double progress;
  final String progressText;
  final Color color;
  final bool isComplete;

  const _DailyTask({
    required this.icon,
    required this.title,
    required this.progress,
    required this.progressText,
    required this.color,
    required this.isComplete,
  });
}

class _DailyTaskCard extends StatelessWidget {
  final _DailyTask task;

  const _DailyTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: task.isComplete
                    ? Colors.green.withValues(alpha: 0.2)
                    : task.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                task.isComplete ? Icons.check : task.icon,
                color: task.isComplete ? Colors.green : task.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Title and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: task.isComplete ? TextDecoration.lineThrough : null,
                      color: task.isComplete
                          ? context.colorScheme.outline
                          : context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 6,
                            backgroundColor: context.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              task.isComplete ? Colors.green : task.color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.progressText,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueReadingAsync = ref.watch(continueReadingProvider);

    return continueReadingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continue Reading',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return GestureDetector(
                    onTap: () => context.go('/library/book/${book.id}'),
                    child: SizedBox(
                      width: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: context.colorScheme.surfaceContainerHighest,
                                image: book.coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(book.coverUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: book.coverUrl == null
                                  ? Center(
                                      child: Icon(
                                        Icons.book,
                                        size: 40,
                                        color: context.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.title,
                            style: context.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecommendedBooksSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider(null));

    return booksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        if (books.length <= 1) return const SizedBox.shrink();

        // Show books the user hasn't started yet (mock: just show last few books)
        final recommended = books.reversed.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Books You Might Like',
                  style: context.textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.library),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommended.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = recommended[index];
                  return GestureDetector(
                    onTap: () => context.go('/library/book/${book.id}'),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: context.colorScheme.surfaceContainerHighest,
                                image: book.coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(book.coverUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: book.coverUrl == null
                                  ? Center(
                                      child: Icon(
                                        Icons.book,
                                        size: 36,
                                        color: context.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.title,
                            style: context.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            book.level,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
