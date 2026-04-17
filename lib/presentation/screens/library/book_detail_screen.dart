import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_access_provider.dart';
import '../../providers/book_download_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/teacher_preview_provider.dart';
import '../../utils/app_icons.dart';
import '../../widgets/book/level_badge.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/library/download_button.dart';

class BookDetailScreen extends ConsumerWidget {

  const BookDetailScreen({
    super.key,
    required this.bookId,
  });
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('📖 BookDetailScreen: bookId=$bookId');
    final canAccess = ref.watch(canAccessBookProvider(bookId));
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    debugPrint('📖 BookDetailScreen: bookAsync=$bookAsync');
    final chaptersAsync = ref.watch(chaptersProvider(bookId));
    final chaptersWithStatus = ref.watch(chaptersWithLockStatusProvider(bookId));
    final progressAsync = ref.watch(readingProgressProvider(bookId));
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(currentUserIdProvider);
    final isTeacher = ref.watch(isTeacherPreviewModeProvider);

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
        body: ErrorStateWidget(
          message: 'Failed to load book details',
          onRetry: () => ref.invalidate(bookByIdProvider(bookId)),
        ),
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
        // Also hide if progress is 0%
        final hasProgress = progress != null &&
            !progress.id.startsWith('new-') &&
            progress.completionPercentage > 0;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Collapsible AppBar with cover image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  if (userId != null)
                    BookDownloadButton(bookId: bookId, userId: userId),
                  const SizedBox(width: 8),
                ],
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
                          if (book.author != null) ...[
                            Icon(
                              Icons.person,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              book.author!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Stats row
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _StatItem(
                            icon: Icons.schedule,
                            label: book.readingTime.isNotEmpty
                                ? book.readingTime
                                : '${book.estimatedMinutes ?? 0} min',
                          ),
                          _StatItem(
                            icon: Icons.menu_book,
                            label: '${book.chapterCount} chapters',
                          ),
                          if (book.wordCount != null)
                            _StatItem(
                              icon: Icons.text_fields,
                              label: '${(book.wordCount! / 1000).toStringAsFixed(1)}k words',
                            ),
                          if (book.lexileScore != null)
                            _StatItem(
                              icon: Icons.speed,
                              label: '${book.lexileScore}L',
                            ),
                        ],
                      ),

                      // Teacher actions (top of screen — Start Reading + Assign)
                      if (isTeacher) ...[
                        const SizedBox(height: 20),
                        _TeacherBookDetailActions(
                          bookId: bookId,
                          bookTitle: book.title,
                          chapterCount: book.chapterCount,
                          chaptersAsync: chaptersAsync,
                        ),
                      ],

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
                  child: ErrorStateWidget(
                    message: 'Failed to load chapters',
                    onRetry: () => ref.invalidate(chaptersProvider(bookId)),
                  ),
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

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = chaptersWithStatus[index];
                        final isCurrentChapter = progress?.chapterId == item.chapter.id;

                        return _ChapterTile(
                          number: index + 1,
                          title: item.chapter.title,
                          duration: item.chapter.estimatedMinutes,
                          isCompleted: item.isCompleted,
                          isCurrent: isCurrentChapter,
                          isLocked: item.isLocked,
                          onTap: () {
                            final isPreview =
                                ref.read(isTeacherPreviewModeProvider);
                            context.go(
                              isPreview
                                  ? AppRoutes.teacherReaderPath(
                                      bookId,
                                      item.chapter.id,
                                    )
                                  : AppRoutes.readerPath(
                                      bookId,
                                      item.chapter.id,
                                    ),
                            );
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
          bottomNavigationBar: isTeacher
              ? null
              : _BookDetailFAB(
                  bookId: bookId,
                  bookTitle: book.title,
                  chapterCount: book.chapterCount,
                  hasProgress: hasProgress,
                  isCompleted: progress?.isCompleted ?? false,
                  chaptersAsync: chaptersAsync,
                  progress: progress,
                  userId: userId,
                ),
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

class _BookDetailFAB extends ConsumerWidget {
  const _BookDetailFAB({
    required this.bookId,
    required this.bookTitle,
    required this.chapterCount,
    required this.hasProgress,
    required this.isCompleted,
    required this.chaptersAsync,
    required this.progress,
    required this.userId,
  });

  final String bookId;
  final String bookTitle;
  final int chapterCount;
  final bool hasProgress;
  final bool isCompleted;
  final AsyncValue<List<Chapter>> chaptersAsync;
  final ReadingProgress? progress;
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTeacher = ref.watch(isTeacherPreviewModeProvider);

    if (isTeacher) {
      return _TeacherBookDetailActions(
        bookId: bookId,
        bookTitle: bookTitle,
        chapterCount: chapterCount,
        chaptersAsync: chaptersAsync,
      );
    }

    // Hide button if book is completed
    if (isCompleted) {
      return const SizedBox.shrink();
    }

    // Check if quiz is ready (all chapters read, quiz exists, not passed)
    final isQuizReady =
        ref.watch(isQuizReadyProvider(bookId)).valueOrNull ?? false;

    if (isQuizReady) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 8),
          child: Center(
            heightFactor: 1.0,
            child: SizedBox(
              width: 280,
              height: 54,
              child: GameButton(
                label: 'Take the Quiz',
                icon: AppIcons.quiz(),
                variant: GameButtonVariant.primary,
                onPressed: () {
                  context.push(AppRoutes.bookQuizPath(bookId));
                },
              ),
            ),
          ),
        ),
      );
    }

    // Student sees "Start/Continue Reading" button (GameButton island style)
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 8),
        child: Center(
          heightFactor: 1.0,
          child: SizedBox(
            width: 280,
            height: 54,
            child: GameButton(
              label: hasProgress ? 'Continue Reading' : 'Start Reading',
              icon: Icon(hasProgress ? Icons.play_arrow_rounded : Icons.book_rounded),
              variant: GameButtonVariant.primary,
              onPressed: () {
                chaptersAsync.whenData((chapters) {
                  if (chapters.isEmpty) return;

                  String targetChapterId;
                  final currentChapterId = progress?.chapterId;
                  if (currentChapterId != null &&
                      currentChapterId.isNotEmpty) {
                    targetChapterId = currentChapterId;
                  } else {
                    targetChapterId = chapters.first.id;
                  }

                  context.go(AppRoutes.readerPath(bookId, targetChapterId));

                  // Fire-and-forget background download while user reads
                  if (userId != null) {
                    ref.read(bookDownloaderProvider.notifier).downloadBook(
                          bookId,
                          userId: userId!,
                        );
                  }
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherBookDetailActions extends ConsumerWidget {
  const _TeacherBookDetailActions({
    required this.bookId,
    required this.bookTitle,
    required this.chapterCount,
    required this.chaptersAsync,
  });

  final String bookId;
  final String bookTitle;
  final int chapterCount;
  final AsyncValue<List<Chapter>> chaptersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'Start Reading',
                icon: const Icon(Icons.book_rounded),
                variant: GameButtonVariant.primary,
                onPressed: () {
                  chaptersAsync.whenData((chapters) {
                    if (chapters.isEmpty) return;
                    context.go(
                      AppRoutes.teacherReaderPath(bookId, chapters.first.id),
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'Assign Book',
                icon: const Icon(Icons.assignment_add),
                variant: GameButtonVariant.secondary,
                onPressed: () {
                  context.push(
                    AppRoutes.teacherCreateAssignment,
                    extra: {
                      'bookId': bookId,
                      'bookTitle': bookTitle,
                      'chapterCount': chapterCount,
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progress});

  final ReadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = progress.completionPercentage;
    final isQuizPending = percentage >= 100 &&
        !progress.isCompleted &&
        !progress.quizPassed;

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
            AppProgressBar(
              progress: percentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              height: 8,
            ),
            const SizedBox(height: 8),
            Text(
              'Reading time: ${progress.formattedReadingTime}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            // Quiz-ready message
            if (isQuizPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    AppIcons.quiz(size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All chapters read! Take the quiz to complete.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                onPressed: () => context.go(AppRoutes.studentAssignments),
                icon: const Icon(Icons.assignment),
                label: const Text('View My Assignments'),
              ),

              const SizedBox(height: 12),

              // Back to library button
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.library),
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
