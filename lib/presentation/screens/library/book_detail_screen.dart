import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/book_access_provider.dart';
import '../../providers/book_provider.dart';
import '../../widgets/book/level_badge.dart';

class BookDetailScreen extends ConsumerWidget {

  const BookDetailScreen({
    super.key,
    required this.bookId,
  });
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(canAccessBookProvider(bookId));
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    final chaptersAsync = ref.watch(chaptersProvider(bookId));
    final progressAsync = ref.watch(readingProgressProvider(bookId));
    final colorScheme = Theme.of(context).colorScheme;

    // Show locked screen if book is not accessible
    if (!canAccess) {
      return _LockedBookScreen(bookId: bookId);
    }

    return bookAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (book) {
        if (book == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Book not found')),
          );
        }

        final progress = progressAsync.valueOrNull;
        // Check if user has actual progress (not fake in-memory progress)
        // A reading_progress record from DB has a UUID id, fake ones have 'new-' prefix
        final hasProgress = progress != null && !progress.id.startsWith('new-');

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Collapsible AppBar with cover image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image
                      if (book.coverUrl != null)
                        Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return ColoredBox(
                              color: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.book,
                                size: 80,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            );
                          },
                        )
                      else
                        ColoredBox(
                          color: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.book,
                            size: 80,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      // Gradient overlay for better text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    book.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Book content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Level and metadata row
                      Row(
                        children: [
                          LevelBadge(
                            level: book.level,
                            size: LevelBadgeSize.medium,
                          ),
                          const SizedBox(width: 12),
                          if (book.metadata['author'] != null) ...[
                            Icon(
                              Icons.person,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              book.metadata['author'] as String,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        children: [
                          _StatItem(
                            icon: Icons.schedule,
                            label: book.readingTime.isNotEmpty
                                ? book.readingTime
                                : '${book.estimatedMinutes ?? 0} min',
                          ),
                          const SizedBox(width: 24),
                          _StatItem(
                            icon: Icons.menu_book,
                            label: '${book.chapterCount} chapters',
                          ),
                          if (book.wordCount != null) ...[
                            const SizedBox(width: 24),
                            _StatItem(
                              icon: Icons.text_fields,
                              label: '${(book.wordCount! / 1000).toStringAsFixed(1)}k words',
                            ),
                          ],
                        ],
                      ),

                      // Progress indicator (if started)
                      if (hasProgress) ...[
                        const SizedBox(height: 24),
                        _ProgressSection(progress: progress),
                      ],

                      const SizedBox(height: 24),

                      // Description
                      if (book.description != null) ...[
                        Text(
                          'About this book',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          book.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Chapters section
                      Text(
                        'Chapters',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Chapter list
              chaptersAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: Center(child: Text('Error loading chapters: $error')),
                ),
                data: (chapters) {
                  if (chapters.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No chapters available'),
                      ),
                    );
                  }

                  // Get completed chapter IDs for locking logic
                  final completedIds = progress?.completedChapterIds ?? [];

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final chapter = chapters[index];
                        final isCurrentChapter = progress?.chapterId == chapter.id;
                        // Simple check: is this chapter ID in the completed list?
                        final isCompleted = completedIds.contains(chapter.id);

                        // Chapter is locked if any previous chapter is not completed
                        // First chapter (index 0) is never locked
                        bool isLocked = false;
                        if (index > 0) {
                          // Check if all previous chapters are completed
                          for (int i = 0; i < index; i++) {
                            if (!completedIds.contains(chapters[i].id)) {
                              isLocked = true;
                              break;
                            }
                          }
                        }

                        return _ChapterTile(
                          number: index + 1,
                          title: chapter.title,
                          duration: chapter.estimatedMinutes,
                          isCompleted: isCompleted,
                          isCurrent: isCurrentChapter,
                          isLocked: isLocked,
                          onTap: () {
                            context.go('/reader/$bookId/${chapter.id}');
                          },
                        );
                      },
                      childCount: chapters.length,
                    ),
                  );
                },
              ),

              // Bottom padding for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // Navigate to reader with first chapter or continue chapter
              chaptersAsync.whenData((chapters) {
                if (chapters.isEmpty) return;

                String targetChapterId;
                if (progress != null && progress.chapterId != null && progress.chapterId!.isNotEmpty) {
                  targetChapterId = progress.chapterId!;
                } else {
                  targetChapterId = chapters.first.id;
                }

                context.go('/reader/$bookId/$targetChapterId');
              });
            },
            icon: Icon(hasProgress ? Icons.play_arrow : Icons.book),
            label: Text(hasProgress ? 'Continue Reading' : 'Start Reading'),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progress});

  final dynamic progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = progress.completionPercentage as double;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Progress',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reading time: ${progress.formattedReadingTime}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.number,
    required this.title,
    required this.duration,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
    required this.onTap,
  });

  final int number;
  final String title;
  final int? duration;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isLocked
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : isCompleted
                ? colorScheme.primaryContainer
                : isCurrent
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
        child: isCompleted
            ? Icon(Icons.check, color: colorScheme.primary, size: 20)
            : Text(
                '$number',
                style: TextStyle(
                  color: isLocked
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : isCurrent
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isCurrent ? FontWeight.w600 : null,
              color: isLocked ? colorScheme.onSurface.withValues(alpha: 0.5) : null,
            ),
      ),
      subtitle: duration != null
          ? Text(
              '$duration min',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLocked
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
      trailing: isLocked
          ? Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))
          : isCurrent
              ? Icon(Icons.play_circle_fill, color: colorScheme.primary)
              : const Icon(Icons.chevron_right),
      onTap: isLocked ? null : onTap,
    );
  }
}

/// Screen shown when student tries to access a locked book
class _LockedBookScreen extends ConsumerWidget {
  const _LockedBookScreen({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Locked'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              // Book title (if available)
              bookAsync.whenData((book) {
                if (book == null) return const SizedBox.shrink();
                return Text(
                  book.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                );
              }).value ?? const SizedBox.shrink(),

              const SizedBox(height: 16),

              // Message
              Text(
                'This book is locked',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'You have an active reading assignment. Complete your assigned book first to unlock all other books in the library.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Go to assignments button
              FilledButton.icon(
                onPressed: () => context.go('/assignments'),
                icon: const Icon(Icons.assignment),
                label: const Text('View My Assignments'),
              ),

              const SizedBox(height: 12),

              // Back to library button
              OutlinedButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.library_books),
                label: const Text('Back to Library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
