import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/usecases/book/get_books_usecase.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/usecase_providers.dart';

/// Book reading stats for the school
class BookReadingStats {
  final String bookId;
  final String title;
  final String? coverUrl;
  final String level;
  final int totalReaders;
  final int completedReaders;
  final double avgProgress;

  const BookReadingStats({
    required this.bookId,
    required this.title,
    this.coverUrl,
    required this.level,
    required this.totalReaders,
    required this.completedReaders,
    required this.avgProgress,
  });

  double get completionRate =>
      totalReaders > 0 ? (completedReaders / totalReaders) * 100 : 0;
}

/// Provider for book reading statistics
final bookReadingStatsProvider = FutureProvider<List<BookReadingStats>>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return [];

  final getBooksUseCase = ref.watch(getBooksUseCaseProvider);

  // Get all books
  final booksResult = await getBooksUseCase(const GetBooksParams());

  return booksResult.fold(
    (failure) => [],
    (books) async {
      final stats = <BookReadingStats>[];

      for (final book in books) {
        // For now, we'll show placeholder stats
        // In production, this would query reading_progress table
        stats.add(BookReadingStats(
          bookId: book.id,
          title: book.title,
          coverUrl: book.coverUrl,
          level: book.level,
          totalReaders: 0, // Would be fetched from DB
          completedReaders: 0,
          avgProgress: 0,
        ));
      }

      return stats;
    },
  );
});

class ReadingProgressReportScreen extends ConsumerWidget {
  const ReadingProgressReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(bookReadingStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Progress'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bookReadingStatsProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading data', style: context.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(bookReadingStatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (books) {
            if (books.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No books in library',
                      style: context.textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary
                Card(
                  color: context.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          value: '${books.length}',
                          label: 'Total Books',
                          icon: Icons.menu_book,
                        ),
                        _SummaryItem(
                          value: '${books.where((b) => b.completedReaders > 0).length}',
                          label: 'Being Read',
                          icon: Icons.auto_stories,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Library Books',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Book cards
                ...books.map((book) => _BookStatsCard(book: book)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.colorScheme.onPrimaryContainer, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _BookStatsCard extends StatelessWidget {
  const _BookStatsCard({required this.book});

  final BookReadingStats book;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Book cover
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                image: book.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(book.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: book.coverUrl == null
                  ? Icon(Icons.book, color: context.colorScheme.outline)
                  : null,
            ),
            const SizedBox(width: 12),

            // Book info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLevelColor(book.level).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.level,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: _getLevelColor(book.level),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: context.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${book.totalReaders} readers',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${book.completedReaders} completed',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Avg progress
            if (book.totalReaders > 0)
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: book.avgProgress / 100,
                      strokeWidth: 4,
                      backgroundColor: context.colorScheme.surfaceContainerHighest,
                    ),
                    Text(
                      '${book.avgProgress.toStringAsFixed(0)}%',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'A1':
        return Colors.green;
      case 'A2':
        return Colors.lightGreen;
      case 'B1':
        return Colors.orange;
      case 'B2':
        return Colors.deepOrange;
      case 'C1':
        return Colors.red;
      case 'C2':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
